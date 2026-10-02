/**
 * One-off registration utility: writes the two Firestore docs
 * `findDeviceByNodeId` (../db.ts) requires before telemetry or images for a
 * device will be accepted instead of dead-lettered as "unknown device".
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/seedDevice.js --device-id=EVT-EF-002 --org-id=org-001 \
 *     --name="EF-002" --location="Unset" --interval=300
 *
 * Only --device-id and --org-id are required; the rest default to values
 * matching the confirmed real-firmware contract (EVARAFLOW_GROUND_TRUTH.md
 * D-004, D-006) so a bare `node dist/scripts/seedDevice.js --device-id=X
 * --org-id=Y` is enough to unblock ingestion.
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
  const orgId = args["org-id"];
  if (!deviceId || !orgId) {
    console.error(
      "Usage: node dist/scripts/seedDevice.js --device-id=EVT-EF-002 --org-id=org-001 [--name=...] [--location=...] [--interval=300]"
    );
    process.exitCode = 1;
    return;
  }

  const name = args["name"] ?? deviceId;
  const location = args["location"] ?? "Unset";
  const expectedIntervalSeconds = Number(args["interval"] ?? "300");
  // Per D-004/D-006: topic and Drive match key are derived from device_id,
  // not independently configurable.
  const mqttTopic = `evaratech/v1/${deviceId}/telemetry`;
  const driveMatchKey = deviceId;

  // Imported only after arg validation above, so running with no args (or
  // --help) prints usage even when FIREBASE_SERVICE_ACCOUNT_BASE64 isn't
  // set yet, instead of failing on the credential check first.
  await import("../firebaseAdmin");
  const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
  const db = getFirestore();

  await db.collection("deviceIndex").doc(deviceId).set({ orgId });

  await db
    .collection("organizations")
    .doc(orgId)
    .collection("devices")
    .doc(deviceId)
    .set(
      {
        name,
        location,
        mqttTopic,
        driveMatchKey,
        expectedIntervalSeconds,
        consumptionMethod: "totalizer",
        status: "noData",
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  console.log(
    `Registered ${deviceId} under org ${orgId} (topic ${mqttTopic}, drive match key ${driveMatchKey}).`
  );
}

main().catch((err) => {
  console.error("seedDevice failed", err);
  process.exitCode = 1;
});
