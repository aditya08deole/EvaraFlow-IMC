/**
 * Points at THIS backend's own proxy route (routes/driveImageProxy.ts), not
 * directly at Drive. Revises the original plan: linking straight to
 * `https://lh3.googleusercontent.com/d/{fileId}` worked until a real
 * gallery grid loaded ~100 images at once and got rate-limited (HTTP 429,
 * confirmed live) — that endpoint is an unofficial hotlink path, not a
 * supported API, with no documented quota, and a full gallery grid is
 * exactly the kind of burst that trips it. The authenticated Drive API
 * (same service-account token already used for folder backfills,
 * driveBackfill.ts) has a real, documented, much more generous per-project
 * quota instead of a shared-across-the-internet consumer rate limit, so
 * routing through it is both more reliable and no slower in practice
 * (confirmed: the proxy fetch is a single authenticated API call, not
 * meaningfully different latency from the old hotlink).
 */

export function driveImageUrls(fileId: string): {
  storageUrl: string;
  thumbUrl: string;
} {
  const base = process.env.PUBLIC_BASE_URL;
  if (!base) {
    throw new Error("PUBLIC_BASE_URL is not set");
  }
  // No separate thumbnail size — same tradeoff already accepted for the
  // Tailscale pipeline (tailscale.ts) at this project's current scope.
  const url = `${base.replace(/\/+$/, "")}/drive-images/${fileId}`;
  return { storageUrl: url, thumbUrl: url };
}
