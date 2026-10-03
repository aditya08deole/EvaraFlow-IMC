/**
 * Unit tests for tailscalePoll.ts. POLL_CUTOFF is fixed at module load
 * time (roughly "now"), so test filenames use clearly past (2020) or
 * clearly future (2099) dates to land on either side of it regardless of
 * when the test actually runs — avoids needing to mock the system clock.
 *
 * ../tailscale needs no mocking: tailscaleProxyUrls just builds a URL
 * string from PUBLIC_BASE_URL, no network call.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as db from "../db";
import { pollTailscaleImages } from "../tailscalePoll";

const DEVICE = { orgId: "org-001", deviceId: "EVT-EF-002", expectedIntervalSeconds: 300 };

function fakeListResponse(nodes: Record<string, string[]>) {
  return { ok: true, status: 200, statusText: "OK", json: async () => ({ nodes, count: 0 }) };
}

test("ignores historical images (captured before this poller started)", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    fakeListResponse({ "EVT-EF-002": ["EVT-EF-002_20200101_120000.jpg"] })
  );
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  await pollTailscaleImages();

  assert.equal(insertImage.mock.callCount(), 0);
});

test("ingests a new-since-startup image not already indexed", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    fakeListResponse({ "EVT-EF-002": ["EVT-EF-002_20991231_120000.jpg"] })
  );
  t.mock.method(db, "imageExists", async () => false);
  t.mock.method(db, "findDeviceByNodeId", async (nodeId: string) =>
    nodeId === DEVICE.deviceId ? DEVICE : null
  );
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  await pollTailscaleImages();

  assert.equal(insertImage.mock.callCount(), 1);
  const fields = insertImage.mock.calls[0].arguments[0] as {
    orgId: unknown;
    deviceId: unknown;
    fileName: string;
    source: string;
    storageUrl: string;
  };
  assert.equal(fields.orgId, "org-001");
  assert.equal(fields.deviceId, "EVT-EF-002");
  assert.equal(fields.fileName, "EVT-EF-002_20991231_120000.jpg");
  assert.equal(fields.source, "tailscale");
  assert.equal(
    fields.storageUrl,
    "http://test-backend.example.com/tailscale-images/EVT-EF-002/EVT-EF-002_20991231_120000.jpg"
  );
});

test("skips an image already indexed, without inserting again", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    fakeListResponse({ "EVT-EF-002": ["EVT-EF-002_20991231_120000.jpg"] })
  );
  t.mock.method(db, "imageExists", async () => true);
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  await pollTailscaleImages();

  assert.equal(insertImage.mock.callCount(), 0);
});

test("does nothing when /list itself fails, without throwing", async (t) => {
  t.mock.method(globalThis, "fetch", async () => ({
    ok: false,
    status: 500,
    statusText: "Internal Server Error",
    json: async () => ({}),
  }));
  const insertImage = t.mock.method(db, "insertImage", async () => {});

  await assert.doesNotReject(pollTailscaleImages());
  assert.equal(insertImage.mock.callCount(), 0);
});
