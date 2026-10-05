/**
 * Pull-based auto-sync for Drive-sourced devices, mirroring
 * tailscalePoll.ts's pattern. Without this, a device's `driveFolderId`
 * (lib/widgets/add_edit_device_dialog.dart, persisted on the device doc
 * as of EVARAFLOW_GROUND_TRUTH.md D-034) only ever got checked the one
 * time an admin opened that dialog and saved it — any photo added to the
 * folder afterward just sat there unindexed until someone manually
 * reopened the dialog and resubmitted the same folder link. Confirmed as
 * a real, user-reported gap for EVT-EF-004 specifically (50 photos had
 * piled up unindexed), not a guess.
 *
 * Checked every 2.5 minutes (close to MQTT's own responsiveness, per
 * explicit user request), but the expensive part — backfillFolder()'s
 * one imageExists() Firestore read per file in the folder — only runs
 * when something has actually changed. Every tick does one cheap
 * `listFolderFiles` call (just id+name, one or a few Drive API pages,
 * no Firestore reads at all) and compares the file count against what
 * the *previous* tick saw for that folder; the full backfill only fires
 * when the count has grown. A large folder (thousands of files, see
 * D-022) sitting unchanged therefore costs one Drive list call every
 * 2.5 minutes, not thousands of Firestore reads.
 *
 * The per-folder "last known count" lives in memory, not Firestore —
 * simplest thing that works for a single always-on process (same
 * pattern as tailscalePoll.ts's own module-level state). Resets to
 * "unknown" on every process restart, which just means the next tick
 * after a restart always does one real backfill pass regardless of
 * whether anything changed — self-correcting, not a bug.
 */

import { getFirestore } from "firebase-admin/firestore";
import { backfillFolder, getDriveAccessToken, listFolderFiles } from "./driveBackfill";

const lastKnownFileCount = new Map<string, number>();

export async function pollDriveFolders(): Promise<void> {
  const db = getFirestore();
  const snap = await db
    .collectionGroup("devices")
    .where("imageSource", "==", "drive")
    .get();

  for (const doc of snap.docs) {
    const folderId = doc.data().driveFolderId as string | undefined;
    if (!folderId) continue;
    try {
      const accessToken = await getDriveAccessToken();
      const files = await listFolderFiles(accessToken, folderId);
      const previousCount = lastKnownFileCount.get(folderId);

      if (previousCount !== undefined && files.length <= previousCount) {
        continue; // Nothing new since last tick — skip the expensive pass.
      }

      const result = await backfillFolder(folderId);
      lastKnownFileCount.set(folderId, files.length);
      if (result.indexed > 0) {
        console.log(
          `pollDriveFolders: ${doc.id} — indexed ${result.indexed} new photo(s) from folder ${folderId}`
        );
      }
    } catch (err) {
      console.error(
        `pollDriveFolders: backfill of ${doc.id} (folder ${folderId}) failed`,
        err
      );
    }
  }
}
