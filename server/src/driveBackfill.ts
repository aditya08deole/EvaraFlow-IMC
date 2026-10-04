/**
 * Shared core for indexing every image ALREADY SITTING in a Drive folder
 * into Firestore, for images uploaded before notifyBackend() existed in a
 * device's Apps Script (so nothing ever POSTed them to
 * /ingest/drive-image). Without this, the dashboard — which only ever
 * reads Firestore, never Drive directly — shows nothing for a folder full
 * of real photos.
 *
 * Used by both server/src/scripts/backfillDriveImages.ts (CLI, one-off) and
 * server/src/routes/backfillDriveImages.ts (HTTP route, triggered from the
 * Add/Edit Device dialog) — the logic lives here once so neither can drift
 * from the other.
 *
 * Reuses the same Firebase service-account key as everything else in this
 * server (no separate Drive credential needed), requesting it an
 * additional OAuth scope (drive.readonly) via google-auth-library, which
 * is already a dependency of firebase-admin. This only works because the
 * folder is shared "Anyone with the link" — that sharing grants read
 * access to any authenticated Google identity presenting the folder id,
 * including this service account, with no explicit per-folder sharing
 * step required.
 */

import { GoogleAuth } from "google-auth-library";
import { getFirestore } from "firebase-admin/firestore";
import { serviceAccount } from "./firebaseAdmin";
import { findDeviceByNodeId, imageExists, insertImage } from "./db";
import { driveImageUrls } from "./drive";
import { FILENAME_RE, parseCapturedAt } from "./routes/ingestDriveImage";

export interface DriveFile {
  id: string;
  name: string;
}

// Exported for routes/driveImageProxy.ts, which needs the exact same
// authenticated access — fetching a file's actual bytes via the Drive API
// is a different call than listing a folder, but needs the same token.
export async function getDriveAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: serviceAccount as object,
    scopes: ["https://www.googleapis.com/auth/drive.readonly"],
  });
  return (await auth.getAccessToken()) as string;
}

export async function listFolderFiles(
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

export interface BackfillResult {
  totalFiles: number;
  indexed: number;
  alreadyIndexed: number;
  badFilename: number;
}

/**
 * Lists `folderId`'s contents and indexes every file matching the
 * {node_id}_{YYYYMMDD}_{HHMMSS}.jpg contract that isn't already indexed.
 * Logs per-file progress — the only visibility mechanism when this runs
 * fire-and-forget from the HTTP route (see routes/backfillDriveImages.ts).
 */
export async function backfillFolder(folderId: string): Promise<BackfillResult> {
  const accessToken = await getDriveAccessToken();

  const files = await listFolderFiles(accessToken, folderId);
  console.log(`backfillFolder: found ${files.length} file(s) in folder ${folderId}.`);

  let indexed = 0;
  let alreadyIndexed = 0;
  let badFilename = 0;

  for (const file of files) {
    const match = FILENAME_RE.exec(file.name);
    if (!match) {
      badFilename++;
      continue;
    }
    const [, nodeId, dateStr, timeStr] = match;

    if (await imageExists(file.id)) {
      alreadyIndexed++;
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
    indexed++;
  }

  console.log(
    `backfillFolder: done for ${folderId}. indexed=${indexed} alreadyIndexed=${alreadyIndexed} badFilename=${badFilename}`
  );

  return { totalFiles: files.length, indexed, alreadyIndexed, badFilename };
}

export interface PruneResult {
  checked: number;
  removed: number;
}

/**
 * The reverse of backfillFolder: removes any indexed image whose Drive
 * file no longer exists in `folderId` (deleted, or moved elsewhere) —
 * without this, deleting a photo from Drive does nothing to this app,
 * since nothing here ever re-checks what it already indexed. Does one
 * Drive list call for the whole folder rather than one existence check
 * per indexed image, since a device can have thousands of images.
 */
export async function pruneDeletedImages(
  folderId: string,
  orgId: string,
  deviceId: string
): Promise<PruneResult> {
  const accessToken = await getDriveAccessToken();
  const files = await listFolderFiles(accessToken, folderId);
  const stillPresent = new Set(files.map((f) => f.id));

  const db = getFirestore();
  const snap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("images")
    .where("deviceId", "==", deviceId)
    .get();

  let removed = 0;
  for (const doc of snap.docs) {
    const driveFileId = doc.data().driveFileId as string | undefined;
    if (driveFileId && !stillPresent.has(driveFileId)) {
      await doc.ref.delete();
      removed++;
    }
  }

  console.log(
    `pruneDeletedImages: checked ${snap.size} indexed image(s) for ${deviceId} against folder ${folderId}, removed ${removed} no longer present.`
  );

  return { checked: snap.size, removed };
}
