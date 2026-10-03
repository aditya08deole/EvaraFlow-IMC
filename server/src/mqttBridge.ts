/**
 * Direct MQTT subscriber bridge — an alternative to the EMQX Rule Engine's
 * HTTP action (which requires broker-admin access to configure and isn't
 * something this codebase controls). When MQTT_HOST is set, this process
 * connects to the broker itself as a subscriber and feeds every message on
 * MQTT_TOPIC_FILTER through the same `processTelemetryMessage` validation
 * and dead-letter path that /ingest/telemetry uses, so both routes behave
 * identically. Entirely optional: leave MQTT_HOST unset to disable this and
 * rely on the HTTP webhook only.
 *
 * Uses its own client ID (not the device's) — connecting with the same
 * client ID as a currently-connected device would make the broker
 * disconnect one of the two connections (MQTT client IDs must be unique).
 *
 * Protocol defaults to WSS (MQTT over WebSocket Secure, effectively port
 * 443), not raw MQTT/1883. Confirmed by direct TCP test: some networks
 * (this one included) allow outbound 443 but block outbound 1883 outright
 * — WSS reaches the exact same broker and topics, just over a transport
 * far less likely to be firewalled. Set MQTT_PROTOCOL=mqtt to use raw
 * MQTT/1883 instead, e.g. once this runs somewhere with unrestricted
 * egress and you'd rather avoid the WebSocket framing overhead.
 */

import mqtt from "mqtt";
import { processTelemetryMessage } from "./routes/ingestTelemetry";

export function startMqttBridge(): void {
  const host = process.env.MQTT_HOST;
  if (!host) return;

  const protocol = (process.env.MQTT_PROTOCOL || "wss") as "wss" | "mqtt";
  const port = Number(process.env.MQTT_PORT) || (protocol === "wss" ? 443 : 1883);
  const wsPath = process.env.MQTT_WS_PATH || "/mqtt";
  const topicFilter = process.env.MQTT_TOPIC_FILTER || "evaratech/v1/+/telemetry";
  const clientId = `evaraflow-server-bridge-${Math.random().toString(16).slice(2, 10)}`;

  const client = mqtt.connect({
    host,
    port,
    protocol,
    path: protocol === "wss" ? wsPath : undefined,
    clientId,
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    reconnectPeriod: 5000,
  });

  client.on("connect", () => {
    console.log(
      `mqttBridge connected to ${protocol}://${host}:${port}${protocol === "wss" ? wsPath : ""} as ${clientId}`
    );
    client.subscribe(topicFilter, (err) => {
      if (err) {
        console.error(`mqttBridge failed to subscribe to ${topicFilter}`, err);
      } else {
        console.log(`mqttBridge subscribed to ${topicFilter}`);
      }
    });
  });

  client.on("message", (topic, payloadBuf) => {
    processTelemetryMessage(topic, payloadBuf.toString("utf8")).catch((err) => {
      console.error(`mqttBridge failed to process message on ${topic}`, err);
    });
  });

  client.on("error", (err) => {
    console.error("mqttBridge connection error", err);
  });

  client.on("reconnect", () => {
    console.log("mqttBridge reconnecting...");
  });
}
