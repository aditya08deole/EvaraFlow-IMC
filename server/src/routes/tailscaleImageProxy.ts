/**
 * Serves a Tailscale-hosted photo to any dashboard viewer, by fetching it
 * live from the Tailscale server on every request — see tailscale.ts for
 * why there's no durable copy (Firebase Storage would need the paid
 * Blaze plan; the user explicitly doesn't want that).
 *
 * This route itself needs no auth: it only ever serves a JPEG whose
 * node id and filename the caller already got from a Firestore `images`
 * doc, which is itself access-controlled by firestore.rules. Path
 * segments are restricted to the same safe character set server_v3.py
 * itself uses for node ids (and that this project's filenames are always
 * built from — see FILENAME_RE in ingestDriveImage.ts) specifically to
 * block path traversal (`../`) in what's otherwise a direct pass-through
 * to another server's file path.
 *
 * Needs `Access-Control-Allow-Origin` (confirmed necessary live, not
 * assumed — this is exactly why the images didn't render at first): the
 * Flutter dashboard's Image.network on web decodes via CanvasKit, which
 * fetches bytes through the browser's own HTTP client and is therefore
 * subject to CORS, unlike a plain `<img>` tag. Drive images never hit
 * this because they're served from Google's CDN, which already sends a
 * permissive CORS header. Every other route in this file is called by a
 * device or webhook, never a browser, so this is the first one that
 * actually needs it.
 */

import type { Request, Response } from "express";

// server_v3.py's own sanitise_node_id() allows only these characters in a
// node id — never a dot, so no filename extension to worry about there.
const SAFE_NODE_ID_RE = /^[A-Za-z0-9_-]+$/;
// Filenames are {node_id}_{YYYYMMDD}_{HHMMSS}.jpg (FILENAME_RE in
// ingestDriveImage.ts) — same safe character set plus the one literal dot
// before the extension.
const SAFE_FILENAME_RE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9]+$/;

export async function tailscaleImageProxyHandler(
  req: Request,
  res: Response
): Promise<void> {
  const { nodeId, filename } = req.params;
  if (!SAFE_NODE_ID_RE.test(nodeId) || !SAFE_FILENAME_RE.test(filename)) {
    res.status(400).send("invalid node id or filename");
    return;
  }

  const base = process.env.TAILSCALE_IMAGE_BASE_URL;
  if (!base) {
    res.status(503).send("TAILSCALE_IMAGE_BASE_URL is not configured");
    return;
  }

  const upstreamUrl = `${base.replace(/\/+$/, "")}/images/${nodeId}/${filename}`;
  try {
    const upstream = await fetch(upstreamUrl);
    if (!upstream.ok) {
      res.status(upstream.status === 404 ? 404 : 502).send("could not fetch image");
      return;
    }
    const bytes = Buffer.from(await upstream.arrayBuffer());
    res.set("Content-Type", upstream.headers.get("content-type") ?? "image/jpeg");
    res.set("Access-Control-Allow-Origin", "*");
    // Long + immutable: a captured photo's bytes at a given filename never
    // change, so once a viewer's browser has fetched one, it should never
    // need to again — this is what actually makes repeat views fast, since
    // the live fetch to the Tailscale server only has to happen once per
    // browser per photo, not on every gallery open.
    res.set("Cache-Control", "public, max-age=31536000, immutable");
    res.send(bytes);
  } catch (err) {
    console.error(`tailscaleImageProxy: failed to reach ${upstreamUrl}`, err);
    res.status(502).send("could not reach the Tailscale image server");
  }
}
