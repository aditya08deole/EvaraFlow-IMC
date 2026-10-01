/**
 * Railway has no Google Application Default Credentials the way a Cloud
 * Function or Cloud Run instance does, so unlike the original Firebase
 * Functions version of this backend, this process authenticates with an
 * explicit service-account key. The key is injected as a base64-encoded
 * env var (FIREBASE_SERVICE_ACCOUNT_BASE64) set directly in Railway's
 * Variables tab — it must never be committed to the repo or pasted
 * anywhere outside that UI.
 *
 * The same parsed credential is reused for Drive access in drive.ts, so
 * only one key exists for this whole service. Its service-account email
 * needs Viewer access shared on the Drive folder devices upload into —
 * a one-time manual step in Drive's sharing UI.
 */

import { cert, initializeApp, type ServiceAccount } from "firebase-admin/app";

function loadServiceAccount(): ServiceAccount {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!b64) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_BASE64 is not set. See server/.env.example."
    );
  }
  const json = Buffer.from(b64, "base64").toString("utf8");
  return JSON.parse(json) as ServiceAccount;
}

export const serviceAccount = loadServiceAccount();

initializeApp({
  credential: cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
});
