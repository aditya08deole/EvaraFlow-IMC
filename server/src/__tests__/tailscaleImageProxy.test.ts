/**
 * Unit tests for routes/tailscaleImageProxy.ts. Mocks the global fetch
 * (the only I/O this handler does) rather than hitting a real server.
 */
import "./_setupEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import { tailscaleImageProxyHandler } from "../routes/tailscaleImageProxy";
import { fakeReq, fakeRes } from "./_fakeHttp";

function req(nodeId: string, filename: string) {
  return fakeReq({ params: { nodeId, filename } });
}

test("rejects a node id or filename with path-traversal-unsafe characters", async (t) => {
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("fetch should never be called for an invalid path");
  });
  const res = fakeRes();
  await tailscaleImageProxyHandler(req("../../etc", "passwd"), res);
  assert.equal(res.statusCode, 400);
});

test("streams the image through with its content-type on success", async (t) => {
  const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
  t.mock.method(globalThis, "fetch", async () => ({
    ok: true,
    status: 200,
    headers: new Map([["content-type", "image/jpeg"]]),
    arrayBuffer: async () => bytes,
  }));
  const res = fakeRes();
  await tailscaleImageProxyHandler(req("EVT-EF-002", "EVT-EF-002_20261002_153000.jpg"), res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, bytes);
  // The actual bug this was written to catch: Flutter web's Image.network
  // fetches via CanvasKit, which enforces CORS — without this header the
  // image silently fails to render with no visible error in this app.
  assert.equal(res.headers["Access-Control-Allow-Origin"], "*");
});

test("returns 404 when the upstream server 404s", async (t) => {
  t.mock.method(globalThis, "fetch", async () => ({
    ok: false,
    status: 404,
    headers: new Map(),
    arrayBuffer: async () => Buffer.from([]),
  }));
  const res = fakeRes();
  await tailscaleImageProxyHandler(req("EVT-EF-002", "missing.jpg"), res);
  assert.equal(res.statusCode, 404);
});

test("returns 502 (not a crash) when the Tailscale server is unreachable", async (t) => {
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("connect ECONNREFUSED");
  });
  const res = fakeRes();
  await tailscaleImageProxyHandler(req("EVT-EF-002", "x.jpg"), res);
  assert.equal(res.statusCode, 502);
});
