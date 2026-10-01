/**
 * Firestore access helpers shared by the ingestion routes. Ported from the
 * original Cloud Functions scaffold (functions/src/db.ts) — same schema,
 * same contract, no logic changes. Firestore itself still lives on
 * Firebase; only the compute calling it moved to Railway.
 *
 * Schema (see the Firebase backend plan, session artifact 1 Oct 2026, §04):
 *   organizations/{orgId}/devices/{deviceId}
 *   organizations/{orgId}/devices/{deviceId}/readings_recent/{autoId}
 *   organizations/{orgId}/images/{imageId}
 *   deviceIndex/{deviceId}                 -- flat lookup: deviceId -> orgId,
 *                                              since a bare node_id from an
 *                                              MQTT/webhook payload doesn't
 *                                              tell us which org it belongs
 *                                              to, and devices live under a
 *                                              per-org subcollection.
 *   deadLetters/{autoId}
 */

import "./firebaseAdmin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export interface DeviceRef {
  orgId: string;
  deviceId: string;
  expectedIntervalSeconds: number;
}

const db = () => getFirestore();

/** Looks up which org a device belongs to, then loads the device doc. */
export async function findDeviceByNodeId(
  nodeId: string
): Promise<DeviceRef | null> {
  const indexDoc = await db().collection("deviceIndex").doc(nodeId).get();
  if (!indexDoc.exists) return null;

  const orgId = indexDoc.data()?.orgId as string | undefined;
  if (!orgId) return null;

  const deviceDoc = await db()
    .collection("organizations")
    .doc(orgId)
    .collection("devices")
    .doc(nodeId)
    .get();
  if (!deviceDoc.exists) return null;

  return {
    orgId,
    deviceId: nodeId,
    expectedIntervalSeconds:
      (deviceDoc.data()?.expectedIntervalSeconds as number | undefined) ?? 300,
  };
}

/**
 * TR-5: invalid input goes to dead_letters. It is never repaired, guessed,
 * or silently dropped.
 */
export async function deadLetter(
  source: "mqtt" | "drive",
  payload: unknown,
  reason: string
): Promise<void> {
  await db().collection("deadLetters").add({
    source,
    payload,
    reason,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export async function insertReading(
  device: DeviceRef,
  fields: {
    flowLpm: number | null;
    totalL: number | null;
    raw: unknown;
  }
): Promise<void> {
  const now = FieldValue.serverTimestamp();
  const deviceRef = db()
    .collection("organizations")
    .doc(device.orgId)
    .collection("devices")
    .doc(device.deviceId);

  await db().runTransaction(async (tx) => {
    tx.set(deviceRef.collection("readings_recent").doc(), {
      // device_ts = received_at — the real firmware sends no `ts` field.
      // See EVARAFLOW_GROUND_TRUTH.md D-012; both columns kept distinct in
      // the schema so a future firmware update can populate deviceTs
      // independently without a migration.
      deviceTs: now,
      receivedAt: now,
      flowLpm: fields.flowLpm,
      totalL: fields.totalL,
      sensorStatus: "ok", // not device-reported (D-005) — firmware only
      // publishes already-validated readings, so an accepted message is
      // "ok" by construction.
      raw: fields.raw,
    });
    tx.update(deviceRef, { lastSeenAt: now });
  });
}

export async function imageExists(driveFileId: string): Promise<boolean> {
  // Images are stored across all orgs' organizations/{orgId}/images
  // subcollections, so a plain doc lookup by driveFileId needs a
  // collection-group query — idempotency check, TR-4.
  const snap = await db()
    .collectionGroup("images")
    .where("driveFileId", "==", driveFileId)
    .limit(1)
    .get();
  return !snap.empty;
}

export async function insertImage(fields: {
  orgId: string | null;
  deviceId: string | null; // null = Unassigned, TR-10
  driveFileId: string;
  fileName: string;
  capturedAt: string | null;
  thumbUrl: string;
  storageUrl: string;
}): Promise<void> {
  const target = fields.orgId
    ? db().collection("organizations").doc(fields.orgId).collection("images")
    : db().collection("unassignedImages"); // no org known — platform-wide queue

  await target.add({
    deviceId: fields.deviceId,
    driveFileId: fields.driveFileId,
    fileName: fields.fileName,
    capturedAt: fields.capturedAt,
    receivedAt: FieldValue.serverTimestamp(),
    thumbUrl: fields.thumbUrl,
    storageUrl: fields.storageUrl,
  });
}
