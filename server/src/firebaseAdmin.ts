/**
 * Railway has no Google Application Default Credentials the way a Cloud
 * Function or Cloud Run instance does, so unlike the original Firebase
 * Functions version of this backend, this process authenticates with an
 * explicit service-account key. The key is injected as a base64-encoded
 * env var (FIREBASE_SERVICE_ACCOUNT_BASE64) set directly in Railway's
 * Variables tab — it must never be committed to the repo or pasted
 * anywhere outside that UI.
 *
 * Used for Firestore throughout. Also used for Firebase Storage, but only
 * by the Tailscale image pipeline (tailscale.ts) — Drive images still never
 * touch Storage (see drive.ts, which links to Drive-hosted images directly
 * instead of caching them). Storage needs FIREBASE_STORAGE_BUCKET passed
 * explicitly per call (getStorage().bucket(name)) since initializeApp()
 * below doesn't set a default bucket.
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
});
