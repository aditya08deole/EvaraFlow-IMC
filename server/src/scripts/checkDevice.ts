/**
 * Read-only diagnostic: shows a device's current Firestore state, its most
 * recent accepted readings, and its most recent dead letters, side by side.
 *
 * Exists because of a real incident (EVARAFLOW_GROUND_TRUTH.md D-016/D-017):
 * diagnosing a mismatch between this project's data and EvaraTech's own Ops
 * panel required hand-written one-off scripts that opened a *second* MQTT
 * connection using the device's own live credentials — which plausibly
 * caused the already-running bridge to miss some of the device's real
 * messages while those debug connections were open. This script never
 * touches MQTT at all, only Firestore, so running it can't ever interfere
 * with a live device's connection to the broker. Use this instead of a new
 * ad-hoc MQTT listener whenever the question is "what has this device
 * actually sent us" rather than "is the broker reachable right now."
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/checkDevice.js --device-id=EVT-EF-002 [--readings=5] [--dead-letters=10]
 */

import "dotenv/config";

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
  const deviceId = args["device-id"];
  if (!deviceId) {
    console.error(
      "Usage: node dist/scripts/checkDevice.js --device-id=EVT-EF-002 [--readings=5] [--dead-letters=10]"
    );
    process.exitCode = 1;
    return;
  }
  const readingsLimit = Number(args["readings"] ?? "5");
  const deadLetterScanLimit = Number(args["dead-letters-scanned"] ?? "500");
  const deadLetterShowLimit = Number(args["dead-letters"] ?? "10");

  await import("../firebaseAdmin");
  const { getFirestore } = await import("firebase-admin/firestore");
  const db = getFirestore();

  const indexDoc = await db.collection("deviceIndex").doc(deviceId).get();
  if (!indexDoc.exists) {
    console.log(
      `deviceIndex/${deviceId} does not exist — this device has never been registered. Run seedDevice.js first, or every message from it will dead-letter as "unknown device".`
    );
    process.exitCode = 1;
    return;
  }
  const orgId = indexDoc.data()?.orgId as string;
  console.log(`orgId: ${orgId}\n`);

  const deviceRef = db
    .collection("organizations")
    .doc(orgId)
    .collection("devices")
    .doc(deviceId);
  const deviceDoc = await deviceRef.get();
  console.log("Device doc:");
  console.log(JSON.stringify(deviceDoc.data(), null, 2));

  const recent = await deviceRef
    .collection("readings_recent")
    .orderBy("receivedAt", "desc")
    .limit(readingsLimit)
    .get();
  console.log(`\nLast ${recent.size} accepted reading(s):`);
  recent.forEach((d) => console.log(JSON.stringify(d.data())));

  const deadLetters = await db
    .collection("deadLetters")
    .orderBy("createdAt", "desc")
    .limit(deadLetterScanLimit)
    .get();
  const matching = deadLetters.docs.filter((d) =>
    JSON.stringify(d.data()).includes(deviceId)
  );
  console.log(
    `\nMost recent dead letter(s) mentioning ${deviceId} (of ${deadLetters.size} scanned, newest first):`
  );
  if (matching.length === 0) console.log("(none found in the scanned window)");
  matching.slice(0, deadLetterShowLimit).forEach((d) => {
    const data = d.data();
    console.log(
      data.createdAt?.toDate?.(),
      "-",
      data.reason,
      "-",
      JSON.stringify(data.payload)
    );
  });
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("checkDevice failed", err);
    process.exitCode = 1;
  });
