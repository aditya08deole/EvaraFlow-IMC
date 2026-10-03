/**
 * Unit tests for routes/ingestTailscaleImage.ts — same mocking approach as
 * ingestDriveImage.test.ts (../db monkey-patched per test, no real
 * Firestore call). ../tailscale DOES need mocking here, unlike ../drive:
 * fetchAndStoreTailscaleImage makes a real network fetch and a real
 * Storage upload, so every test below replaces it rather than letting it
 * run for real.
 *
 * Filename shape matches server_v3.py's own
 * `"{}_{}.jpg".format(node_id, timestamp)` where
 * timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") — the same
 * {node_id}_{YYYYMMDD}_{HHMMSS}.jpg shape already confirmed for Drive
 * (EVARAFLOW_GROUND_TRUTH.md D-006).
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as db from "../db";
import * as tailscale from "../tailscale";
import { ingestTailscaleImageHandler } from "../routes/ingestTailscaleImage";
import { fakeReq, fakeRes } from "./_fakeHttp";

const AUTH_HEADERS = { "X-Webhook-Secret": "test-tailscale-secret" };
const DEVICE = { orgId: "org-001", deviceId: "EVT-EF-002", expectedIntervalSeconds: 300 };
const REAL_FILENAME = "EVT-EF-002_20261002_153000.jpg";
const FAKE_HOSTED_URL =
  "https://storage.googleapis.com/test-bucket.appspot.com/tailscale-images/EVT-EF-002/EVT-EF-002_20261002_153000.jpg";

test("rejects with 401 when X-Webhook-Secret is missing or wrong", async () => {
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({ body: {}, headers: { "X-Webhook-Secret": "wrong" } }),
    res
  );
  assert.equal(res.statusCode, 401);
});

test("dead-letters and 200s when node_id or filename is missing", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({ body: { node_id: "EVT-EF-002" }, headers: AUTH_HEADERS }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(deadLetter.mock.calls[0].arguments[2], "missing node_id or filename");
});

test("dead-letters filenames that don't match {node_id}_{YYYYMMDD}_{HHMMSS}.jpg", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: "not-the-right-shape.jpg" },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.match(deadLetter.mock.calls[0].arguments[2] as string, /does not match/);
});

test("dead-letters when the filename's node_id disagrees with the request body's", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: "EVT-EF-003_20261002_153000.jpg" },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.match(
    deadLetter.mock.calls[0].arguments[2] as string,
    /does not match node_id in request body/
  );
});

test("is idempotent: a filename already indexed is 200'd without re-inserting", async (t) => {
  t.mock.method(db, "imageExists", async () => true);
  const insertImage = t.mock.method(db, "insertImage", async () => {});
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: REAL_FILENAME },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(insertImage.mock.callCount(), 0);
});

test("files an image from an unknown device as Unassigned, not a dead letter", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async () => null);
  t.mock.method(tailscale, "fetchAndStoreTailscaleImage", async () => ({
    storageUrl: FAKE_HOSTED_URL,
    thumbUrl: FAKE_HOSTED_URL,
  }));
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-UNKNOWN", filename: "EVT-UNKNOWN_20261002_153000.jpg" },
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
  assert.equal(fields.storageUrl, FAKE_HOSTED_URL);
});

test("indexes a valid image for a registered device with the re-hosted Storage URL, tagged source: tailscale", async (t) => {
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async (nodeId: string) =>
    nodeId === DEVICE.deviceId ? DEVICE : null
  );
  t.mock.method(tailscale, "fetchAndStoreTailscaleImage", async () => ({
    storageUrl: FAKE_HOSTED_URL,
    thumbUrl: FAKE_HOSTED_URL,
  }));
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: REAL_FILENAME },
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
    source: string;
    driveFileId: string;
  };
  assert.equal(fields.orgId, "org-001");
  assert.equal(fields.deviceId, "EVT-EF-002");
  assert.equal(fields.capturedAt, "2026-10-02T15:30:00Z");
  assert.equal(fields.storageUrl, FAKE_HOSTED_URL);
  assert.equal(fields.thumbUrl, FAKE_HOSTED_URL);
  assert.equal(fields.source, "tailscale");
  assert.equal(fields.driveFileId, REAL_FILENAME);
});

test("dead-letters (200, not 500) when fetching/storing from the Tailscale server fails", async (t) => {
  const deadLetter = t.mock.method(db, "deadLetter", async () => {});
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async () => DEVICE);
  const insertImage = t.mock.method(db, "insertImage", async () => {});
  t.mock.method(tailscale, "fetchAndStoreTailscaleImage", async () => {
    throw new Error("fetching http://laptop:5000/images/... returned 404 Not Found");
  });

  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: REAL_FILENAME },
      headers: AUTH_HEADERS,
    }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(insertImage.mock.callCount(), 0);
  assert.match(
    deadLetter.mock.calls[0].arguments[2] as string,
    /could not fetch\/store image.*404 Not Found/
  );
});

test("returns 500 (not a crash) when the Firestore insert throws", async (t) => {
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async () => DEVICE);
  t.mock.method(tailscale, "fetchAndStoreTailscaleImage", async () => ({
    storageUrl: FAKE_HOSTED_URL,
    thumbUrl: FAKE_HOSTED_URL,
  }));
  t.mock.method(db, "insertImage", async () => {
    throw new Error("Firestore unavailable");
  });
  const res = fakeRes();
  await ingestTailscaleImageHandler(
    fakeReq({
      body: { node_id: "EVT-EF-002", filename: REAL_FILENAME },
      headers: AUTH_HEADERS,
    }),
    res
  );
  assert.equal(res.statusCode, 500);
});
