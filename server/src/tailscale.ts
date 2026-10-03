/**
 * Fetches an image's bytes from the Flask image server (server_v3.py) over
 * the Tailscale network, and re-hosts them in Firebase Storage so the
 * dashboard can show them to *any* viewer — not just ones on that tailnet.
 *
 * This is a deliberate change from the Drive pipeline's "never cache
 * bytes" approach (drive.ts): Drive images are already served from a
 * public Google CDN URL, so linking to that URL directly works for anyone.
 * server_v3.py's `/images/<node>/<filename>` is only reachable over a
 * private Tailscale network — a URL built from it would be broken for any
 * viewer not on that tailnet. The only way to make a Tailscale-hosted
 * photo work for a general audience without asking the user to expose
 * their laptop to the public internet (Tailscale Funnel) is for this
 * backend to fetch the bytes itself and host a copy somewhere public.
 *
 * Consequence worth knowing: THIS BACKEND must itself be able to reach
 * TAILSCALE_IMAGE_BASE_URL over the network to fetch the bytes. That's
 * true today because the backend runs locally, on the same machine/tailnet
 * as server_v3.py. If this backend is later deployed to Railway (as
 * server/README.md describes), Railway's container is NOT on the user's
 * tailnet by default — this fetch would fail every time until Tailscale is
 * also set up there (e.g. a `tailscale/tailscale` sidecar joined with an
 * auth key). Not solved here; flagged for whoever deploys this next.
 */

import { getStorage } from "firebase-admin/storage";

export async function fetchAndStoreTailscaleImage(
  nodeId: string,
  fileName: string
): Promise<{ storageUrl: string; thumbUrl: string }> {
  const base = process.env.TAILSCALE_IMAGE_BASE_URL;
  if (!base) {
    throw new Error("TAILSCALE_IMAGE_BASE_URL is not set");
  }
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
  if (!bucketName) {
    throw new Error("FIREBASE_STORAGE_BUCKET is not set");
  }

  const sourceUrl = `${base.replace(/\/+$/, "")}/images/${nodeId}/${fileName}`;
  const response = await fetch(sourceUrl);
  if (!response.ok) {
    throw new Error(
      `fetching ${sourceUrl} returned ${response.status} ${response.statusText}`
    );
  }
  const bytes = Buffer.from(await response.arrayBuffer());

  // Namespaced so these never collide with anything the Drive pipeline
  // might one day also put in Storage, and so they're easy to find/prune
  // by node.
  const storagePath = `tailscale-images/${nodeId}/${fileName}`;
  const bucket = getStorage().bucket(bucketName);
  const file = bucket.file(storagePath);
  await file.save(bytes, {
    contentType: "image/jpeg",
    public: true,
  });

  const url = `https://storage.googleapis.com/${bucketName}/${storagePath}`;
  // No separate thumbnail size, same as the Flask server's own single-size
  // storage — fine at demo scope (max ~2 devices).
  return { storageUrl: url, thumbUrl: url };
}
