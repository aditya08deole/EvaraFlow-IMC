/**
 * One-off reconciliation script: indexes every image ALREADY SITTING in a
 * Drive folder into Firestore, for images uploaded before notifyBackend()
 * existed in the device's Apps Script (so nothing ever POSTed them to
 * /ingest/drive-image). Without this, the dashboard — which only ever
 * reads Firestore, never Drive directly — shows nothing for a folder full
 * of real photos.
 *
 * Reuses the same Firebase service-account key as everything else in this
 * server (no separate Drive credential needed), requesting it an
 * additional OAuth scope (drive.readonly) via google-auth-library, which
 * is already a transitive dependency of firebase-admin. This only works
 * because the folder is shared "Anyone with the link" — that sharing
 * grants read access to any authenticated Google identity presenting the
 * folder id, including this service account, with no explicit per-folder
 * sharing step required.
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/backfillDriveImages.js --folder-id=195GCcit75OqLfxwGgbvxpzx6OK7exmWs
 */

import "dotenv/config";
import { GoogleAuth } from "google-auth-library";
import { serviceAccount } from "../firebaseAdmin";
import { findDeviceByNodeId, imageExists, insertImage } from "../db";
import { driveImageUrls } from "../drive";
import { FILENAME_RE, parseCapturedAt } from "../routes/ingestDriveImage";

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const arg of argv) {
    const match = /^--([^=]+)=(.*)$/.exec(arg);
    if (match) out[match[1]] = match[2];
  }
  return out;
}

interface DriveFile {
  id: string;
  name: string;
}

async function listFolderFiles(
  accessToken: string,
  folderId: string
): Promise<DriveFile[]> {
  const files: DriveFile[] = [];
  let pageToken: string | undefined;
  do {
    const url = new URL("https://www.googleapis.com/drive/v3/files");
    url.searchParams.set("q", `'${folderId}' in parents and trashed = false`);
    url.searchParams.set("fields", "nextPageToken, files(id, name)");
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
      throw new Error(
        `Drive API list failed: HTTP ${res.status} ${await res.text()}`
      );
    }
    const body = (await res.json()) as {
      files?: DriveFile[];
      nextPageToken?: string;
    };
    files.push(...(body.files ?? []));
    pageToken = body.nextPageToken;
  } while (pageToken);
  return files;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const folderId = args["folder-id"];
  if (!folderId) {
    console.error(
      "Usage: node dist/scripts/backfillDriveImages.js --folder-id=<drive folder id>"
    );
    process.exitCode = 1;
    return;
  }

  const auth = new GoogleAuth({
    credentials: serviceAccount as object,
    scopes: ["https://www.googleapis.com/auth/drive.readonly"],
  });
  const accessToken = (await auth.getAccessToken()) as string;

  const files = await listFolderFiles(accessToken, folderId);
  console.log(`Found ${files.length} file(s) in folder ${folderId}.`);

  let indexed = 0;
  let skippedExisting = 0;
  let skippedBadName = 0;

  for (const file of files) {
    const match = FILENAME_RE.exec(file.name);
    if (!match) {
      console.log(`  skip (name doesn't match contract): ${file.name}`);
      skippedBadName++;
      continue;
    }
    const [, nodeId, dateStr, timeStr] = match;

    if (await imageExists(file.id)) {
      skippedExisting++;
      continue;
    }

    const device = await findDeviceByNodeId(nodeId);
    const { storageUrl, thumbUrl } = driveImageUrls(file.id);

    await insertImage({
      orgId: device?.orgId ?? null,
      deviceId: device?.deviceId ?? null,
      driveFileId: file.id,
      fileName: file.name,
      capturedAt: parseCapturedAt(dateStr, timeStr),
      thumbUrl,
      storageUrl,
    });
    console.log(`  indexed: ${file.name} (device ${device?.deviceId ?? "Unassigned"})`);
    indexed++;
  }

  console.log(
    `Done. Indexed ${indexed}, already indexed ${skippedExisting}, bad filename ${skippedBadName}.`
  );
}

main().catch((err) => {
  console.error("backfillDriveImages failed", err);
  process.exitCode = 1;
});
