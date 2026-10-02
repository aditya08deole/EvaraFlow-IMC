/**
 * Pipeline A — MQTT telemetry ingestion.
 *
 * Two callers feed the same `processTelemetryMessage` below:
 *   - ingestTelemetryHandler: the EMQX Rule Engine's HTTP action (Option A
 *     in the Firebase backend plan §02), configured in the broker itself,
 *     POSTing to this service's `/ingest/telemetry` route.
 *   - ../mqttBridge: this service connecting to the broker directly as a
 *     subscriber, for when configuring that Rule Engine action isn't
 *     available/done. Same validation, same dead-letter behavior either way.
 *
 * Contract confirmed from real device firmware — EVARAFLOW_GROUND_TRUTH.md
 * D-004/D-005:
 *   topic:   evaratech/v1/{node_id}/telemetry
 *   payload: { node_id, total_liters, flow_rate }  -- no ts, status, or fw.
 */

import type { Request, Response } from "express";
import { deadLetter, findDeviceByNodeId, insertReading } from "../db";
import { recomputeStatusAndAlerts } from "../status";

interface TelemetryPayload {
  node_id?: unknown;
  total_liters?: unknown;
  flow_rate?: unknown;
}

/**
 * Validates and ingests one MQTT message. Shared by the HTTP webhook path
 * and the direct MQTT subscriber bridge so both dead-letter and insert
 * identically. Throws only on genuine infrastructure failure (e.g.
 * Firestore unavailable) — validation rejections are handled internally via
 * dead-lettering and never throw.
 */
export async function processTelemetryMessage(
  topic: string,
  payload: string
): Promise<void> {
  const topicParts = topic.split("/");
  const nodeIdFromTopic = topicParts[2];

  let parsed: TelemetryPayload;
  try {
    parsed = JSON.parse(payload) as TelemetryPayload;
  } catch {
    await deadLetter("mqtt", { topic, payload }, "invalid JSON");
    return;
  }

  const nodeId = parsed.node_id;
  if (typeof nodeId !== "string" || nodeId !== nodeIdFromTopic) {
    await deadLetter("mqtt", parsed, "node_id missing or does not match topic");
    return;
  }

  const flow = typeof parsed.flow_rate === "number" ? parsed.flow_rate : null;
  const total =
    typeof parsed.total_liters === "number" ? parsed.total_liters : null;
  if ((flow !== null && flow < 0) || (total !== null && total < 0)) {
    await deadLetter("mqtt", parsed, "negative value");
    return;
  }
  if (flow === null && total === null) {
    await deadLetter("mqtt", parsed, "both flow_rate and total_liters missing");
    return;
  }

  const device = await findDeviceByNodeId(nodeId);
  if (!device) {
    await deadLetter("mqtt", parsed, `unknown device ${nodeId}`);
    return;
  }

  await insertReading(device, { flowLpm: flow, totalL: total, raw: parsed });
  await recomputeStatusAndAlerts(device);
}

export async function ingestTelemetryHandler(
  req: Request,
  res: Response
): Promise<void> {
  // The whole body is wrapped in one try/catch, including the dead-letter
  // writes below: this process serves every concurrent request on Railway
  // (unlike the original Cloud Functions version, where an uncaught
  // rejection only killed that one invocation), so a transient Firestore
  // failure while writing a dead-letter record must not crash the server
  // out from under unrelated in-flight requests and the health check.
  try {
    if (req.get("X-Webhook-Secret") !== process.env.EMQX_WEBHOOK_SECRET) {
      res.status(401).send("unauthorized");
      return;
    }

    // The EMQX Rule Engine SELECT in the plan returns { topic, payload } —
    // `payload` is the raw MQTT message body (JSON-encoded string).
    const { topic, payload } = req.body as { topic?: string; payload?: string };
    if (typeof topic !== "string" || typeof payload !== "string") {
      await deadLetter("mqtt", req.body, "missing topic or payload");
      res.sendStatus(200); // ack the webhook regardless — see note below
      return;
    }

    await processTelemetryMessage(topic, payload);
    res.sendStatus(200);
  } catch (err) {
    // A genuine infrastructure failure (not a validation rejection) —
    // logged and 500'd so the Rule Engine's own retry (if configured)
    // gets a chance, rather than silently swallowing a write failure.
    console.error("ingestTelemetry failed", err);
    res.sendStatus(500);
  }

  // Note on the 200-on-reject pattern above: EMQX's HTTP action generally
  // doesn't distinguish 4xx from 5xx for retry purposes the way a
  // webhook-aware caller would, so validation rejections (which should
  // never be retried — they'd just dead-letter again) return 200, while
  // genuine write failures (which should be retried) return 500. Confirm
  // this matches your actual EMQX Rule Engine retry configuration before
  // relying on it.
}
