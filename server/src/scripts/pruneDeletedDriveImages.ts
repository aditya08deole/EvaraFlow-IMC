/**
 * One-off CLI wrapper around ../driveBackfill.ts's pruneDeletedImages —
 * removes any indexed image whose Drive file has since been deleted from
 * the given folder. The reverse of backfillDriveImages.ts.
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/pruneDeletedDriveImages.js --folder-id=<id> --org-id=org-001 --device-id=EVT-EF-002
 */

import "dotenv/config";
import { pruneDeletedImages } from "../driveBackfill";

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const arg of argv) {
    const match = /^--([^=]+)=(.*)$/.exec(arg);
    if (match) out[match[1]] = match[2];
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const folderId = args["folder-id"];
  const orgId = args["org-id"];
  const deviceId = args["device-id"];
  if (!folderId || !orgId || !deviceId) {
    console.error(
      "Usage: node dist/scripts/pruneDeletedDriveImages.js --folder-id=<id> --org-id=org-001 --device-id=EVT-EF-002"
    );
    process.exitCode = 1;
    return;
  }

  const result = await pruneDeletedImages(folderId, orgId, deviceId);
  console.log(`Done. Checked ${result.checked}, removed ${result.removed}.`);
}

main().catch((err) => {
  console.error("pruneDeletedDriveImages failed", err);
  process.exitCode = 1;
});
