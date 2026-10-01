/**
 * Downloads an image from Google Drive and caches it in Firebase Storage.
 *
 * Auth: unlike the original Cloud Functions version (which used Application
 * Default Credentials for free), Railway has no ambient Google identity, so
 * this reuses the same service-account key loaded in firebaseAdmin.ts. TR-2's
 * "no Drive credentials in the browser" still holds — this code never runs
 * client-side. The service account's email must be shared (Viewer) on the
 * Drive destination folder the device/Apps Script writes to — a one-time
 * manual step in Drive's sharing UI, not something this code can do for
 * itself.
 */

import { google } from "googleapis";
import { getStorage } from "firebase-admin/storage";
import { serviceAccount } from "./firebaseAdmin";

async function driveClient() {
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount as unknown as Record<string, unknown>,
    scopes: ["https://www.googleapis.com/auth/drive.readonly"],
  });
  return google.drive({ version: "v3", auth });
}

export async function downloadAndCacheImage(
  driveFileId: string,
  storagePathPrefix: string
): Promise<{ storageUrl: string; thumbUrl: string }> {
  const drive = await driveClient();

  const res = await drive.files.get(
    { fileId: driveFileId, alt: "media" },
    { responseType: "arraybuffer" }
  );
  const bytes = Buffer.from(res.data as ArrayBuffer);

  const bucket = getStorage().bucket();
  const displayPath = `${storagePathPrefix}/display.jpg`;
  const thumbPath = `${storagePathPrefix}/thumb.jpg`;

  // Display copy: the original bytes as-is. A resized/compressed thumbnail
  // pass (e.g. via the `sharp` package) is the natural next step here, but
  // kept out of this first version to avoid pulling in a native image
  // dependency before the ingestion path itself is proven end-to-end.
  const displayFile = bucket.file(displayPath);
  await displayFile.save(bytes, { contentType: "image/jpeg", public: false });
  const thumbFile = bucket.file(thumbPath);
  await thumbFile.save(bytes, { contentType: "image/jpeg", public: false });

  const [storageUrl] = await displayFile.getSignedUrl({
    action: "read",
    expires: Date.now() + 1000 * 60 * 60 * 24 * 7, // 7 days
  });
  const [thumbUrl] = await thumbFile.getSignedUrl({
    action: "read",
    expires: Date.now() + 1000 * 60 * 60 * 24 * 7,
  });

  return { storageUrl, thumbUrl };
}
