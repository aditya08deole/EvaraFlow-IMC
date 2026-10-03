/**
 * Points at THIS backend's own proxy route (routes/tailscaleImageProxy.ts),
 * not at Firebase Storage. Revises the original plan: fetching the bytes
 * once and storing a copy in Firebase Storage would have worked, but
 * Cloud Storage for Firebase now requires the paid Blaze plan just to
 * enable it at all (not only once free-tier usage is exceeded) — the user
 * explicitly doesn't want to pay for this, consistent with D-013 already
 * avoiding Blaze once before for the same reason.
 *
 * So: no byte caching anywhere. Every time a viewer's browser loads this
 * URL, THIS backend fetches the current bytes live from the Tailscale
 * server and streams them straight through (see
 * routes/tailscaleImageProxy.ts) — free, no new accounts, no bucket.
 * Tradeoff: a photo stops being viewable if evaratech-vostro-3710 goes
 * offline or this backend loses Tailscale access, until one of them comes
 * back — there's no durable copy the way a Drive-hosted or Storage-hosted
 * image has. Accepted explicitly; revisit only if that turns out to
 * matter in practice.
 *
 * PUBLIC_BASE_URL is THIS backend's own externally-reachable address —
 * http://localhost:8081 for local dev, or the Railway domain once
 * deployed — not the Tailscale server's address (that's
 * TAILSCALE_IMAGE_BASE_URL, read directly by the proxy route instead).
 */

export function tailscaleProxyUrls(
  nodeId: string,
  fileName: string
): { storageUrl: string; thumbUrl: string } {
  const base = process.env.PUBLIC_BASE_URL;
  if (!base) {
    throw new Error("PUBLIC_BASE_URL is not set");
  }
  const url = `${base.replace(/\/+$/, "")}/tailscale-images/${nodeId}/${fileName}`;
  // No separate thumbnail size, same as the Flask server's own single-size
  // storage — fine at demo scope (max ~2 devices).
  return { storageUrl: url, thumbUrl: url };
}
