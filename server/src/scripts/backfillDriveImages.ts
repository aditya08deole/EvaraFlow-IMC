/**
 * One-off CLI wrapper around ../driveBackfill.ts's backfillFolder — see
 * that file for what this actually does and why. The HTTP route at
 * ../routes/backfillDriveImages.ts (triggered from the Add/Edit Device
 * dialog) calls the same shared function; this script exists for manual
 * one-off runs from a terminal.
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/backfillDriveImages.js --folder-id=195GCcit75OqLfxwGgbvxpzx6OK7exmWs
 */

import "dotenv/config";
import { backfillFolder } from "../driveBackfill";

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
  if (!folderId) {
    console.error(
      "Usage: node dist/scripts/backfillDriveImages.js --folder-id=<drive folder id>"
    );
    process.exitCode = 1;
    return;
  }

  const result = await backfillFolder(folderId);
  console.log(
    `Done. Indexed ${result.indexed}, already indexed ${result.alreadyIndexed}, bad filename ${result.badFilename} (of ${result.totalFiles} total).`
  );
}

main().catch((err) => {
  console.error("backfillDriveImages failed", err);
  process.exitCode = 1;
});
