/**
 * Pull-based alternative to ingestTailscaleImage.ts's push webhook —
 * confirmed live against the real EvaraTech image server (D-018): this
 * backend joined the same Tailscale network the server already runs on
 * (`evaratech-vostro-3710`, 100.124.238.71) and can reach its existing
 * `/list` and `/images/<node>/<filename>` routes directly, with zero
 * changes to that server's own code. The user's explicit preference —
 * don't touch the production Python server, pull from our side instead.
 *
 * Both pipelines stay in the codebase: the webhook route still works if
 * someone later does add the push call to server_v3.py, but this poller
 * is what's actually wired up and running.
 *
 * Deliberately NOT a historical backfill: that server's `/list` returned
 * 42,689 images across 6 nodes going back to at least April 2026 the
 * first time this was checked (2026-10-04) — downloading and re-hosting
 * all of that automatically on first boot would be a large, surprising,
 * costly action nobody asked for. POLL_CUTOFF is fixed at module load
 * time, so only images captured from the moment this backend started
 * polling onward are ever considered; the historical backlog is left
 * alone unless a separate, deliberate backfill script is written and run
 * on purpose (mirroring driveBackfill.ts's one-off pattern) — not yet
 * built, since nobody's asked for the historical photos yet.
 */

import { deadLetter, findDeviceByNodeId, imageExists, insertImage } from "./db";
import { fetchAndStoreTailscaleImage } from "./tailscale";
import { FILENAME_RE, parseCapturedAt } from "./routes/ingestDriveImage";

const POLL_CUTOFF = new Date();

interface ListResponse {
  nodes: Record<string, string[]>;
  count: number;
}

export async function pollTailscaleImages(): Promise<void> {
  const base = process.env.TAILSCALE_IMAGE_BASE_URL;
  if (!base) return;

  let listed: ListResponse;
  try {
    const resp = await fetch(`${base.replace(/\/+$/, "")}/list`);
    if (!resp.ok) {
      console.error(`tailscalePoll: /list returned ${resp.status} ${resp.statusText}`);
      return;
    }
    listed = (await resp.json()) as ListResponse;
  } catch (err) {
    console.error("tailscalePoll: failed to reach the Tailscale image server", err);
    return;
  }

  for (const [nodeId, filenames] of Object.entries(listed.nodes)) {
    for (const filename of filenames) {
      const match = FILENAME_RE.exec(filename);
      if (!match) continue; // not this project's naming convention — ignore, not an error
      const [, filenameNodeId, dateStr, timeStr] = match;
      if (filenameNodeId !== nodeId) continue; // folder/filename mismatch — skip, don't guess

      const capturedAt = parseCapturedAt(dateStr, timeStr);
      if (!capturedAt || new Date(capturedAt) <= POLL_CUTOFF) continue; // historical — not this poller's job

      try {
        if (await imageExists(filename)) continue;

        const device = await findDeviceByNodeId(nodeId);
        const { storageUrl, thumbUrl } = await fetchAndStoreTailscaleImage(nodeId, filename);

        await insertImage({
          orgId: device?.orgId ?? null,
          deviceId: device?.deviceId ?? null,
          driveFileId: filename,
          fileName: filename,
          capturedAt,
          thumbUrl,
          storageUrl,
          source: "tailscale",
        });
        console.log(`tailscalePoll: ingested ${nodeId}/${filename}`);
      } catch (err) {
        await deadLetter(
          "tailscale",
          { node_id: nodeId, filename },
          `poll could not fetch/store image: ${err instanceof Error ? err.message : String(err)}`
        );
      }
    }
  }
}
