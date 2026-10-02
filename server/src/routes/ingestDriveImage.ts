/**
 * Pipeline B — Google Drive image ingestion.
 *
 * Called by a one-line addition to the device's existing Apps Script Web
 * App (see the Firebase backend plan §03): immediately after it writes the
 * uploaded JPEG to Drive, it POSTs this service's `/ingest/drive-image`
 * route the Drive file's id and name so we can index it in Firestore.
 * Demo scope: no Storage caching — see drive.ts. This is the "primary push"
 * path; a scheduled reconciliation poll (not yet built) is the safety net
 * for when that POST never arrives.
 *
 * Filename contract confirmed from the real Apps Script — D-006:
 *   {node_id}_{YYYYMMDD}_{HHMMSS}.jpg
 */

import type { Request, Response } from "express";
import { deadLetter, findDeviceByNodeId, imageExists, insertImage } from "../db";
import { driveImageUrls } from "../drive";

const FILENAME_RE = /^([A-Za-z0-9-]+)_(\d{8})_(\d{6})\.jpg$/;

function parseCapturedAt(dateStr: string, timeStr: string): string | null {
  const y = dateStr.slice(0, 4);
  const mo = dateStr.slice(4, 6);
  const d = dateStr.slice(6, 8);
  const h = timeStr.slice(0, 2);
  const mi = timeStr.slice(2, 4);
  const s = timeStr.slice(4, 6);
  const iso = `${y}-${mo}-${d}T${h}:${mi}:${s}Z`;
  const parsed = new Date(iso);
  return Number.isNaN(parsed.getTime()) ? null : iso;
}

export async function ingestDriveImageHandler(
  req: Request,
  res: Response
): Promise<void> {
  // Whole body in one try/catch — see the note in ingestTelemetry.ts on why
  // this matters more on a persistent Railway server than it did on
  // per-invocation Cloud Functions.
  try {
    if (req.get("X-Webhook-Secret") !== process.env.DRIVE_WEBHOOK_SECRET) {
      res.status(401).send("unauthorized");
      return;
    }

    const { fileId, fileName } = req.body as {
      fileId?: unknown;
      fileName?: unknown;
    };
    if (typeof fileId !== "string" || typeof fileName !== "string") {
      await deadLetter("drive", req.body, "missing fileId or fileName");
      res.sendStatus(200);
      return;
    }

    const match = FILENAME_RE.exec(fileName);
    if (!match) {
      await deadLetter(
        "drive",
        { fileId, fileName },
        "filename does not match {node_id}_{YYYYMMDD}_{HHMMSS}.jpg"
      );
      res.sendStatus(200);
      return;
    }
    const [, nodeId, dateStr, timeStr] = match;

    if (await imageExists(fileId)) {
      // TR-4: idempotent. Apps Script or the reconciliation poll may call
      // this more than once for the same file — not an error.
      res.sendStatus(200);
      return;
    }

    const device = await findDeviceByNodeId(nodeId);
    // Unlike telemetry, an unknown device doesn't get dead-lettered here —
    // TR-10: the image is still worth keeping, just filed as Unassigned
    // rather than silently dropped.

    const { storageUrl, thumbUrl } = driveImageUrls(fileId);

    await insertImage({
      orgId: device?.orgId ?? null,
      deviceId: device?.deviceId ?? null,
      driveFileId: fileId,
      fileName,
      capturedAt: parseCapturedAt(dateStr, timeStr),
      thumbUrl,
      storageUrl,
    });
    res.sendStatus(200);
  } catch (err) {
    console.error("ingestDriveImage failed", err);
    res.sendStatus(500);
  }
}
