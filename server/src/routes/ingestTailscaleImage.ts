/**
 * Pipeline C — Tailscale image ingestion (server_v3.py, the Flask image
 * receiver running on a laptop/Pi, reachable over a private Tailscale
 * network). A second, independent way for a device to get an image into
 * this project's gallery, alongside the existing Google Drive pipeline
 * (ingestDriveImage.ts) — both write into the same
 * organizations/{orgId}/images collection, distinguished only by the
 * `source` field.
 *
 * Called by a small addition to server_v3.py's /upload handler: right
 * after it saves a file to images_s/<node_id>/<filename>.jpg, it POSTs
 * this service's /ingest/tailscale-image route with the node id and
 * filename, the same way the Drive pipeline's Apps Script POSTs
 * /ingest/drive-image right after writing to Drive.
 *
 * Filename contract is the *same* one already confirmed for Drive
 * (EVARAFLOW_GROUND_TRUTH.md D-006) — server_v3.py's own
 * `"{}_{}.jpg".format(node_id, timestamp)` with
 * `timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")` produces exactly
 * `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg`, so FILENAME_RE and parseCapturedAt
 * are reused from ingestDriveImage.ts rather than duplicated.
 *
 * Dedupe key: the filename itself, passed as `driveFileId` into
 * imageExists/insertImage (see the comment on insertImage in db.ts) —
 * there's no Drive-style file id for this source, and the filename is
 * already unique per node+timestamp.
 *
 * Reachability, final design: stores a URL pointing at THIS backend's own
 * /tailscale-images/:nodeId/:filename proxy route (tailscaleImageProxyHandler
 * in tailscaleImageProxy.ts), which fetches the actual bytes live on every
 * view instead of caching them anywhere. Went through two earlier designs
 * first — tailnet-only URL, then fetch-once-and-store-in-Firebase-Storage —
 * before landing here once the user confirmed Cloud Storage for Firebase
 * now requires the paid Blaze plan just to enable, which they don't want.
 * See tailscale.ts for the tradeoff this accepts (no durable copy).
 */

import type { Request, Response } from "express";
import { deadLetter, findDeviceByNodeId, imageExists, insertImage } from "../db";
import { tailscaleProxyUrls } from "../tailscale";
import { FILENAME_RE, parseCapturedAt } from "./ingestDriveImage";

export async function ingestTailscaleImageHandler(
  req: Request,
  res: Response
): Promise<void> {
  try {
    if (req.get("X-Webhook-Secret") !== process.env.TAILSCALE_WEBHOOK_SECRET) {
      res.status(401).send("unauthorized");
      return;
    }

    const { node_id, filename } = req.body as {
      node_id?: unknown;
      filename?: unknown;
    };
    if (typeof node_id !== "string" || typeof filename !== "string") {
      await deadLetter("tailscale", req.body, "missing node_id or filename");
      res.sendStatus(200);
      return;
    }

    const match = FILENAME_RE.exec(filename);
    if (!match) {
      await deadLetter(
        "tailscale",
        { node_id, filename },
        "filename does not match {node_id}_{YYYYMMDD}_{HHMMSS}.jpg"
      );
      res.sendStatus(200);
      return;
    }
    const [, filenameNodeId, dateStr, timeStr] = match;
    if (filenameNodeId !== node_id) {
      await deadLetter(
        "tailscale",
        { node_id, filename },
        `node_id in filename (${filenameNodeId}) does not match node_id in request body (${node_id})`
      );
      res.sendStatus(200);
      return;
    }

    if (await imageExists(filename)) {
      // TR-4: idempotent — server_v3.py or a future retry may call this
      // more than once for the same file.
      res.sendStatus(200);
      return;
    }

    const device = await findDeviceByNodeId(node_id);
    // Same as Drive: an unknown device still gets the image filed, as
    // Unassigned (TR-10), not dropped.

    const { storageUrl, thumbUrl } = tailscaleProxyUrls(node_id, filename);

    await insertImage({
      orgId: device?.orgId ?? null,
      deviceId: device?.deviceId ?? null,
      driveFileId: filename,
      fileName: filename,
      capturedAt: parseCapturedAt(dateStr, timeStr),
      thumbUrl,
      storageUrl,
      source: "tailscale",
    });
    res.sendStatus(200);
  } catch (err) {
    console.error("ingestTailscaleImage failed", err);
    res.sendStatus(500);
  }
}
