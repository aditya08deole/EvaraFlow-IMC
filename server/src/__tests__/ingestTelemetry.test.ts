/**
 * Unit tests for routes/ingestTelemetry.ts, run with Node's built-in test
 * runner (`node --test`) — no new dependency, no Firebase emulator, no
 * network call to EMQX. Every test replaces ../db and ../status's exported
 * functions with in-test mocks (via t.mock.method, auto-restored after each
 * test) rather than hitting real Firestore, per the "mock payloads only"
 * testing decision — the real broker is never touched.
 *
 * Payload shapes below match the confirmed real-firmware contract
 * (EVARAFLOW_GROUND_TRUTH.md D-004/D-005), taken directly from the device's
 * MQTT publisher: topic `evaratech/v1/{node_id}/telemetry`, payload
 * `{node_id, total_liters, flow_rate}`.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as db from "../db";
import * as statusModule from "../status";
import { ingestTelemetryHandler } from "../routes/ingestTelemetry";
import { fakeReq, fakeRes } from "./_fakeHttp";

const AUTH_HEADERS = { "X-Webhook-Secret": "test-emqx-secret" };
const DEVICE = { orgId: "org-001", deviceId: "EVT-EF-002", expectedIntervalSeconds: 300 };

function webhookBody(topic: string, payloadObj: unknown) {
  return { topic, payload: JSON.stringify(payloadObj) };
}

test("rejects with 401 when X-Webhook-Secret is missing or wrong", async () => {
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({ body: {}, headers: { "X-Webhook-Secret": "wrong" } }),
    res
  );
  assert.equal(res.statusCode, 401);
});

test("dead-letters and 200s when topic or payload is missing", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({ body: { topic: "evaratech/v1/EVT-EF-002/telemetry" }, headers: AUTH_HEADERS }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.callCount(), 1);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "missing topic or payload");
});

test("dead-letters and 200s on invalid JSON payload", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: { topic: "evaratech/v1/EVT-EF-002/telemetry", payload: "{not json" },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "invalid JSON");
});

test("dead-letters when node_id is missing or does not match the topic", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
        node_id: "EVT-EF-999",
        total_liters: 10,
        flow_rate: 1,
      }),
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(
    deadLetter.mock.calls[0].arguments[2],
    "node_id missing or does not match topic"
  );
});

test("dead-letters on a negative flow_rate or total_liters", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
        node_id: "EVT-EF-002",
        total_liters: -1,
        flow_rate: 1,
      }),
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "negative value");
});

test("dead-letters when both flow_rate and total_liters are missing", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", { node_id: "EVT-EF-002" }),
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(
    deadLetter.mock.calls[0].arguments[2],
    "both flow_rate and total_liters missing"
  );
});

test("dead-letters readings from an unregistered device", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "findDeviceByNodeId", async () => null);
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
        node_id: "EVT-EF-002",
        total_liters: 100,
        flow_rate: 2.5,
      }),
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "unknown device EVT-EF-002");
});

test("accepts a valid real-shape reading for a registered device", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "findDeviceByNodeId", async (nodeId: string) =>
    nodeId === DEVICE.deviceId ? DEVICE : null
  );
  const insertReading = t.mock.method(db, "insertReading", async () => {});
  const recompute = t.mock.method(statusModule, "recomputeStatusAndAlerts", async () => {});

  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
        node_id: "EVT-EF-002",
        total_liters: 1234.5,
        flow_rate: 3.2,
      }),
      headers: AUTH_HEADERS,
    }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.callCount(), 0);
  assert.equal(insertReading.mock.callCount(), 1);
  const [device, fields] = insertReading.mock.calls[0].arguments as [unknown, {
    flowLpm: number | null;
    totalL: number | null;
  }];
  assert.deepEqual(device, DEVICE);
  assert.equal(fields.flowLpm, 3.2);
  assert.equal(fields.totalL, 1234.5);
  assert.equal(recompute.mock.callCount(), 1);
});

test("known gap: two identical valid payloads both insert a reading row (no device_ts dedup yet, D-012 open)", async (t) => {
  t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "findDeviceByNodeId", async () => DEVICE);
  const insertReading = t.mock.method(db, "insertReading", async () => {});
  t.mock.method(statusModule, "recomputeStatusAndAlerts", async () => {});

  const body = webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
    node_id: "EVT-EF-002",
    total_liters: 1234.5,
    flow_rate: 3.2,
  });
  await ingestTelemetryHandler(fakeReq({ body, headers: AUTH_HEADERS }), fakeRes());
  await ingestTelemetryHandler(fakeReq({ body, headers: AUTH_HEADERS }), fakeRes());

  // Documents current behavior, not desired behavior — see D-012 in
  // EVARAFLOW_GROUND_TRUTH.md: the real firmware sends no `ts`, so there is
  // no device_ts to dedupe on yet. This test should start failing (in a
  // good way) once that decision is resolved and insertReading gains a
  // dedup key.
  assert.equal(insertReading.mock.callCount(), 2);
});

test("returns 500 (not a crash) when Firestore lookup throws", async (t) => {
  t.mock.method(db, "findDeviceByNodeId", async () => {
    throw new Error("Firestore unavailable");
  });
  const res = fakeRes();
  await ingestTelemetryHandler(
    fakeReq({
      body: webhookBody("evaratech/v1/EVT-EF-002/telemetry", {
        node_id: "EVT-EF-002",
        total_liters: 1,
        flow_rate: 1,
      }),
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 500);
});
