/**
 * One-off: rewrites every existing Drive-sourced image doc's storageUrl/
 * thumbUrl from the old direct lh3.googleusercontent.com hotlink to this
 * backend's own proxy route (see drive.ts/routes/driveImageProxy.ts for
 * why — that hotlink path returned HTTP 429 under real gallery load).
 * New inserts already get the right URL automatically (drive.ts changed);
 * this just catches up everything inserted before that change, across
 * both organizations/{orgId}/images and unassignedImages.
 *
 * Usage (after `npm run build`, with real env vars set):
 *   node dist/scripts/migrateDriveImageUrls.js
 *   node dist/scripts/migrateDriveImageUrls.js --dry-run
 */

import "dotenv/config";
import "../firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { driveImageUrls } from "../drive";

async function migrateCollection(
  query: FirebaseFirestore.Query,
  label: string,
  dryRun: boolean
): Promise<{ checked: number; updated: number }> {
  const snap = await query.get();
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const fileId = data.driveFileId as string | undefined;
    if (!fileId || data.source === "tailscale") continue;

    const { storageUrl, thumbUrl } = driveImageUrls(fileId);
    if (data.storageUrl === storageUrl && data.thumbUrl === thumbUrl) continue;

    console.log(
      `[${label}] ${doc.ref.path}: ${data.storageUrl} -> ${storageUrl}`
    );
    if (!dryRun) {
      await doc.ref.update({ storageUrl, thumbUrl });
    }
    updated++;
  }
  return { checked: snap.size, updated };
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const db = getFirestore();

  const orgScoped = await migrateCollection(
    db.collectionGroup("images"),
    "organizations/*/images",
    dryRun
  );
  const unassigned = await migrateCollection(
    db.collection("unassignedImages"),
    "unassignedImages",
    dryRun
  );

  console.log(
    `\n${dryRun ? "[dry run] would update" : "Updated"} ${orgScoped.updated}/${orgScoped.checked} org-scoped docs and ${unassigned.updated}/${unassigned.checked} unassigned docs.`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("migrateDriveImageUrls failed", err);
    process.exitCode = 1;
  });
