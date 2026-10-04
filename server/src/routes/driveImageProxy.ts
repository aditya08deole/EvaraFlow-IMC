/**
 * Serves a Drive-hosted photo to any dashboard viewer by fetching it via
 * the authenticated Drive API (the same service-account token used for
 * folder backfills, driveBackfill.ts) instead of linking directly to
 * `https://lh3.googleusercontent.com/d/{fileId}` — see drive.ts for why:
 * that unofficial hotlink path returned HTTP 429 (confirmed live) the
 * moment a real gallery grid loaded ~100 images at once.
 *
 * Mirrors routes/tailscaleImageProxy.ts's shape closely — same reasoning
 * for no auth of its own (the fileId a caller has always came from a
 * firestore.rules-protected `images` doc) and the same long-lived cache
 * header (a captured photo's bytes at a given Drive file id never change).
 */

import type { Request, Response } from "express";
import { getDriveAccessToken } from "../driveBackfill";

// Drive file ids are alphanumeric plus - and _ (confirmed by every real
// id seen from this project's own backfills) — restricted here mainly so
// a malformed id fails fast with a clear 400 instead of an opaque 404/500
// from the Drive API.
const SAFE_FILE_ID_RE = /^[A-Za-z0-9_-]+$/;

export async function driveImageProxyHandler(
  req: Request,
  res: Response
): Promise<void> {
  const { fileId } = req.params;
  if (!SAFE_FILE_ID_RE.test(fileId)) {
    res.status(400).send("invalid file id");
    return;
  }

  try {
    const accessToken = await getDriveAccessToken();
    const upstream = await fetch(
      `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`,
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    if (!upstream.ok) {
      res
        .status(upstream.status === 404 ? 404 : 502)
        .send("could not fetch image from Drive");
      return;
    }
    const bytes = Buffer.from(await upstream.arrayBuffer());
    res.set(
      "Content-Type",
      upstream.headers.get("content-type") ?? "image/jpeg"
    );
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Cache-Control", "public, max-age=31536000, immutable");
    res.send(bytes);
  } catch (err) {
    console.error(`driveImageProxy: failed to fetch file ${fileId}`, err);
    res.status(502).send("could not reach the Drive API");
  }
}
