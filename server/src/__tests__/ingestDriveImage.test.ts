/**
 * Unit tests for routes/ingestDriveImage.ts — see the header note in
 * ingestTelemetry.test.ts for the mocking approach (../db is monkey-patched
 * per test; no real Firestore call is ever made). ../drive needs no
 * mocking since it just builds a URL string from a fileId, no network call.
 *
 * Filename shape matches the real Apps Script's output, built from the
 * device code's `filename = f"{NODE_ID}_{ts_str}.jpg"` where
 * ts_str = capture_ts.strftime("%Y%m%d_%H%M%S") (EVARAFLOW_GROUND_TRUTH.md
 * D-006): `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg`.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as db from "../db";
import { ingestDriveImageHandler } from "../routes/ingestDriveImage";
import { fakeReq, fakeRes } from "./_fakeHttp";

const AUTH_HEADERS = { "X-Webhook-Secret": "test-drive-secret" };
const DEVICE = { orgId: "org-001", deviceId: "EVT-EF-002", expectedIntervalSeconds: 300 };
const REAL_FILENAME = "EVT-EF-002_20261002_153000.jpg";

test("rejects with 401 when X-Webhook-Secret is missing or wrong", async () => {
  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({ body: {}, headers: { "X-Webhook-Secret": "wrong" } }),
    res
  );
  assert.equal(res.statusCode, 401);
});

test("dead-letters and 200s when fileId or fileName is missing", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({ body: { fileId: "abc123" }, headers: AUTH_HEADERS }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "missing fileId or fileName");
});

test("dead-letters filenames that don't match {node_id}_{YYYYMMDD}_{HHMMSS}.jpg", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({
      body: { fileId: "abc123", fileName: "not-the-right-shape.jpg" },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.match(
    deadLetter.mock.calls[0].arguments[2] as string,
    /does not match/
  );
});

test("is idempotent: a fileId already indexed is 200'd without re-inserting", async (t) => {
  t.mock.method(db, "imageExists", async () => true);
  const insertImage = t.mock.method(db, "insertImage", async () => {});
  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({ body: { fileId: "dup-1", fileName: REAL_FILENAME }, headers: AUTH_HEADERS }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(insertImage.mock.callCount(), 0);
});

test("files an image from an unknown device as Unassigned, not a dead letter", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async () => null);
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({
      body: { fileId: "unassigned-1", fileName: "EVT-UNKNOWN_20261002_153000.jpg" },
      headers: AUTH_HEADERS,
    }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.callCount(), 0);
  const fields = insertImage.mock.calls[0].arguments[0] as {
    orgId: unknown;
    deviceId: unknown;
    storageUrl: string;
  };
  assert.equal(fields.orgId, null);
  assert.equal(fields.deviceId, null);
  assert.equal(fields.storageUrl, "http://test-backend.example.com/drive-images/unassigned-1");
});

test("indexes a valid image for a registered device with this backend's own proxy URL", async (t) => {
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async (nodeId: string) =>
    nodeId === DEVICE.deviceId ? DEVICE : null
  );
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({
      body: { fileId: "real-1", fileName: REAL_FILENAME },
      headers: AUTH_HEADERS,
    }),
    res
  );

  assert.equal(res.statusCode, 200);
  const fields = insertImage.mock.calls[0].arguments[0] as {
    orgId: unknown;
    deviceId: unknown;
    capturedAt: string | null;
    storageUrl: string;
    thumbUrl: string;
  };
  assert.equal(fields.orgId, "org-001");
  assert.equal(fields.deviceId, "EVT-EF-002");
  assert.equal(fields.capturedAt, "2026-10-02T15:30:00Z");
  assert.equal(fields.storageUrl, "http://test-backend.example.com/drive-images/real-1");
  assert.equal(fields.thumbUrl, "http://test-backend.example.com/drive-images/real-1");
});

test("returns 500 (not a crash) when the Firestore insert throws", async (t) => {
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async () => DEVICE);
  t.mock.method(db, "insertImage", async () => {
    throw new Error("Firestore unavailable");
  });
  const res = fakeRes();
  await ingestDriveImageHandler(
    fakeReq({ body: { fileId: "err-1", fileName: REAL_FILENAME }, headers: AUTH_HEADERS }),
    res
  );
  assert.equal(res.statusCode, 500);
});
