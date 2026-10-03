/**
 * Admin-triggered Drive folder backfill — called from the "Google Drive
 * Folder" field in the Add/Edit Device dialog (lib/widgets/add_edit_device_dialog.dart)
 * so a device's pre-existing photos show up in the gallery without needing
 * someone to run server/src/scripts/backfillDriveImages.ts by hand.
 *
 * Fire-and-forget by design: a real folder can hold thousands of files
 * (we've seen 2,250 take a few minutes), so this responds 202 immediately
 * rather than holding the HTTP request — and therefore the Flutter UI —
 * open for that long. The trade-off: a Drive-side failure (folder not
 * shared, folder doesn't exist) only surfaces in this server's logs, not
 * back to the admin who triggered it. Acceptable for this demo-scope
 * feature; revisit with a job-status mechanism if that gap matters later.
 */

import type { Request, Response } from "express";
import { backfillFolder } from "../driveBackfill";

// Defense in depth: this id ends up inside a Drive API `q` filter string
// built with simple interpolation (see driveBackfill.ts) — reject
// anything that doesn't look like a real Drive id before it gets near
// that string, rather than trusting Drive's API to reject it safely.
const DRIVE_FOLDER_ID_RE = /^[A-Za-z0-9_-]{10,}$/;

export async function backfillDriveImagesHandler(
  req: Request,
  res: Response
): Promise<void> {
  const { folderId } = req.body as { folderId?: unknown };
  if (typeof folderId !== "string" || !DRIVE_FOLDER_ID_RE.test(folderId)) {
    res.status(400).json({ error: "folderId missing or not a plausible Drive folder id" });
    return;
  }

  res.status(202).json({ message: "Backfill started in the background." });

  backfillFolder(folderId).catch((err) => {
    console.error(`backfillDriveImagesHandler: backfill of ${folderId} failed`, err);
  });
}
