/**
 * Unit tests for mqttBridge.ts's retained-message handling — run with
 * Node's built-in test runner. Mocks ../db and ../routes/ingestTelemetry's
 * exported functions (via t.mock.method, auto-restored after each test)
 * rather than connecting to a real broker, per the same pattern used in
 * ingestTelemetry.test.ts.
 *
 * Real incident this guards against: a frozen reading (node_id "rpitest",
 * a fixed total_liters value) kept reappearing identically on every
 * broker reconnect — a RETAIN-flagged publish being replayed, not a live
 * republish. Trusting it as live data let it eventually get accepted as a
 * genuine totalizer reset, corrupting the real device's baseline.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as db from "../db";
import * as ingestTelemetryModule from "../routes/ingestTelemetry";
import { handleMqttMessage } from "../mqttBridge";

const TOPIC = "evaratech/v1/EVT-EF-002/telemetry";
const PAYLOAD = Buffer.from(JSON.stringify({ node_id: "rpitest", total_liters: 492902.51, flow_rate: 0 }));

test("dead-letters a retained message instead of processing it as live telemetry", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const processTelemetryMessage = t.mock.method(
    ingestTelemetryModule,
    "processTelemetryMessage",
    async () => {}
  );

  handleMqttMessage(TOPIC, PAYLOAD, { retain: true });
  // handleMqttMessage fires the async dead-letter call without awaiting it
  // (same fire-and-forget shape as the real client.on("message", ...)
  // callback), so give its microtask a tick to run before asserting.
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(processTelemetryMessage.mock.callCount(), 0);
  assert.equal(deadLetter.mock.callCount(), 1);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "retained message replay, not live telemetry — ignored");
});

test("processes a non-retained message normally", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const processTelemetryMessage = t.mock.method(
    ingestTelemetryModule,
    "processTelemetryMessage",
    async () => {}
  );

  handleMqttMessage(TOPIC, PAYLOAD, { retain: false });
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(processTelemetryMessage.mock.callCount(), 1);
  assert.deepEqual(processTelemetryMessage.mock.calls[0].arguments, [TOPIC, PAYLOAD.toString("utf8")]);
  assert.equal(deadLetter.mock.callCount(), 0);
});
