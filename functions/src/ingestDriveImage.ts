/**
 * Pipeline B — Google Drive image ingestion.
 *
 * Called by a one-line addition to the device's existing Apps Script Web
 * App (see the Firebase backend plan §03): immediately after it writes the
 * uploaded JPEG to Drive, it POSTs this function the Drive file's id and
 * name so we can cache it into Storage and index it in Firestore. This is
 * the "primary push" path; a scheduled reconciliation poll (not yet built)
 * is the safety net for when that POST never arrives.
 *
 * Filename contract confirmed from the real Apps Script — D-006:
 *   {node_id}_{YYYYMMDD}_{HHMMSS}.jpg
 */

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { deadLetter, findDeviceByNodeId, imageExists, insertImage } from "./db";
import { downloadAndCacheImage } from "./drive";

const webhookSecret = defineSecret("DRIVE_WEBHOOK_SECRET");

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

export const ingestDriveImage = onRequest(
  { secrets: [webhookSecret], cors: false },
  async (req, res) => {
    if (req.get("X-Webhook-Secret") !== webhookSecret.value()) {
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
      await deadLetter("drive", { fileId, fileName }, "filename does not match {node_id}_{YYYYMMDD}_{HHMMSS}.jpg");
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

    try {
      const storagePrefix = device
        ? `organizations/${device.orgId}/images/${fileId}`
        : `unassigned/images/${fileId}`;
      const { storageUrl, thumbUrl } = await downloadAndCacheImage(fileId, storagePrefix);

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
      logger.error("ingestDriveImage failed", err);
      res.sendStatus(500);
    }
  }
);
