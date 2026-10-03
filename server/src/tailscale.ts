/**
 * Same "store a URL, don't cache bytes" approach as drive.ts, pointed at
 * the Flask image server (server_v3.py) instead of Google Drive. Per the
 * user's explicit choice, this project only needs to work for viewers on
 * the same Tailscale network as that server, so a plain tailnet address is
 * enough — no Tailscale Funnel, no public reachability.
 *
 * TAILSCALE_IMAGE_BASE_URL is that server's tailnet address, e.g.
 * `http://your-laptop.your-tailnet.ts.net:5000` (MagicDNS) or
 * `http://100.x.y.z:5000` (plain Tailscale IP) — either works the same way.
 */

export function tailscaleImageUrls(
  nodeId: string,
  fileName: string
): { storageUrl: string; thumbUrl: string } {
  const base = process.env.TAILSCALE_IMAGE_BASE_URL;
  if (!base) {
    throw new Error("TAILSCALE_IMAGE_BASE_URL is not set");
  }
  // The Flask server has no separate thumbnail size, so both URLs point at
  // the same full-size image — fine at demo scope (max ~2 devices).
  const url = `${base.replace(/\/+$/, "")}/images/${nodeId}/${fileName}`;
  return { storageUrl: url, thumbUrl: url };
}
