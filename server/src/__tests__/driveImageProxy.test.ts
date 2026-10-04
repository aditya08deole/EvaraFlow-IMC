/**
 * Unit tests for routes/driveImageProxy.ts. Mocks getDriveAccessToken
 * (../driveBackfill) and the global fetch (the Drive API call) rather than
 * hitting a real Drive file.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as driveBackfill from "../driveBackfill";
import { driveImageProxyHandler } from "../routes/driveImageProxy";
import { fakeReq, fakeRes } from "./_fakeHttp";

function req(fileId: string) {
  return fakeReq({ params: { fileId } });
}

test("rejects a file id with unsafe characters", async (t) => {
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("fetch should never be called for an invalid id");
  });
  const res = fakeRes();
  await driveImageProxyHandler(req("../../etc/passwd"), res);
  assert.equal(res.statusCode, 400);
});

test("streams the image through with CORS and long-cache headers on success", async (t) => {
  t.mock.method(driveBackfill, "getDriveAccessToken", async () => "fake-token");
  const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
  const fetchMock = t.mock.method(globalThis, "fetch", async (url: string, opts: any) => {
    assert.match(url, /drive\/v3\/files\/real-1\?alt=media/);
    assert.equal(opts.headers.Authorization, "Bearer fake-token");
    return {
      ok: true,
      status: 200,
      headers: new Map([["content-type", "image/jpeg"]]),
      arrayBuffer: async () => bytes,
    };
  });
  const res = fakeRes();
  await driveImageProxyHandler(req("real-1"), res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, bytes);
  assert.equal(res.headers["Access-Control-Allow-Origin"], "*");
  assert.equal(res.headers["Cache-Control"], "public, max-age=31536000, immutable");
  assert.equal(fetchMock.mock.callCount(), 1);
});

test("returns 404 when Drive 404s (file deleted/moved)", async (t) => {
  t.mock.method(driveBackfill, "getDriveAccessToken", async () => "fake-token");
  t.mock.method(globalThis, "fetch", async () => ({
    ok: false,
    status: 404,
    headers: new Map(),
    arrayBuffer: async () => Buffer.from([]),
  }));
  const res = fakeRes();
  await driveImageProxyHandler(req("deleted-1"), res);
  assert.equal(res.statusCode, 404);
});

test("returns 502 (not a crash) when the Drive API is unreachable", async (t) => {
  t.mock.method(driveBackfill, "getDriveAccessToken", async () => {
    throw new Error("auth failed");
  });
  const res = fakeRes();
  await driveImageProxyHandler(req("real-1"), res);
  assert.equal(res.statusCode, 502);
});
