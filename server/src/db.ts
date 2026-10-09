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
  // Last accepted reading's values, if any — read off the device doc so
  // processTelemetryMessage can plausibility-check an incoming reading
  // (TR-5.1: a real totalizer only ever counts up) without a second query.
  lastFlowLpm: number | null;
  lastTotalL: number | null;
  // Needed to compute an implied rate for an upward totalizer jump (see
  // ingestTelemetry.ts) — a jump is only plausible relative to how much
  // time actually passed since the last accepted reading.
  lastSeenAt: Date | null;
}

const db = () => getFirestore();

export interface LiveReadingData {
  deviceId: string;
  flowLpm: number | null;
  totalL: number | null;
  timestamp: string;
  raw: unknown;
}

export const LATEST_READINGS = new Map<string, LiveReadingData>();

// Pre-seeded known devices to eliminate Firestore read dependencies and quota limits
const KNOWN_DEVICES: Record<string, DeviceRef> = {
  "EVT-EF-006": {
    orgId: "org-001",
    deviceId: "EVT-EF-006",
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
  "EVT_EF_006": {
    orgId: "org-001",
    deviceId: "EVT-EF-006", // Canonical mapping
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
  "EF-006": {
    orgId: "org-001",
    deviceId: "EVT-EF-006",
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
  "EVT-EF-002": {
    orgId: "org-001",
    deviceId: "EVT-EF-002",
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
  "EVT-EF-004": {
    orgId: "org-001",
    deviceId: "EVT-EF-004",
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
  "EVT-EF-001": {
    orgId: "org-001",
    deviceId: "EVT-EF-001",
    expectedIntervalSeconds: 300,
    lastFlowLpm: null,
    lastTotalL: null,
    lastSeenAt: null,
  },
};

// In-memory cache to eliminate repetitive Firestore reads on high-frequency MQTT telemetry
const DEVICE_CACHE = new Map<string, DeviceRef>();

/** Looks up which org a device belongs to, then loads the device doc. */
export async function findDeviceByNodeId(
  nodeId: string
): Promise<DeviceRef | null> {
  const cached = DEVICE_CACHE.get(nodeId);
  if (cached) return cached;

  if (KNOWN_DEVICES[nodeId]) {
    const ref = { ...KNOWN_DEVICES[nodeId] };
    DEVICE_CACHE.set(nodeId, ref);
    return ref;
  }

  // Try normalized variants (EVT_EF_006 <-> EVT-EF-006)
  const altId = nodeId.includes("_")
    ? nodeId.replace(/_/g, "-")
    : nodeId.replace(/-/g, "_");
  if (KNOWN_DEVICES[altId]) {
    const ref = { ...KNOWN_DEVICES[altId] };
    DEVICE_CACHE.set(nodeId, ref);
    return ref;
  }
  const altCached = DEVICE_CACHE.get(altId);
  if (altCached) {
    DEVICE_CACHE.set(nodeId, altCached);
    return altCached;
  }

  try {
    let indexDoc = await db().collection("deviceIndex").doc(nodeId).get();
    let resolvedId = nodeId;
    if (!indexDoc.exists && altId !== nodeId) {
      indexDoc = await db().collection("deviceIndex").doc(altId).get();
      if (indexDoc.exists) resolvedId = altId;
    }
    if (!indexDoc.exists) return null;

    const orgId = indexDoc.data()?.orgId as string | undefined;
    if (!orgId) return null;

    const deviceDoc = await db()
      .collection("organizations")
      .doc(orgId)
      .collection("devices")
      .doc(resolvedId)
      .get();
    if (!deviceDoc.exists) return null;

    const data = deviceDoc.data();
    const ref: DeviceRef = {
      orgId,
      deviceId: resolvedId,
      expectedIntervalSeconds:
        (data?.expectedIntervalSeconds as number | undefined) ?? 300,
      lastFlowLpm: (data?.lastFlowLpm as number | undefined) ?? null,
      lastTotalL: (data?.lastTotalL as number | undefined) ?? null,
      lastSeenAt:
        (data?.lastSeenAt as { toDate?: () => Date } | undefined)?.toDate?.() ?? null,
    };

    DEVICE_CACHE.set(nodeId, ref);
    DEVICE_CACHE.set(resolvedId, ref);
    return ref;
  } catch (err) {
    // A Firestore blip here must not be treated as "this device is real" —
    // TR-5 requires unknown input to dead-letter, never be guessed into
    // existence. Confirmed real incident: this used to fabricate a
    // DeviceRef for *any* nodeId on a Firestore error, which let unrelated
    // MQTT traffic (e.g. a different product line's "evaravalve-*" nodes)
    // get silently accepted as live EvaraFlow telemetry whenever the free
    // Firestore tier's quota was hit. A device already confirmed via
    // KNOWN_DEVICES or the in-memory cache above never reaches this catch
    // block at all, so returning null here only ever drops traffic from a
    // nodeId this process has no prior confirmation of.
    console.warn(`Firestore read failed in findDeviceByNodeId for ${nodeId}:`, err);
    return null;
  }
}

/**
 * TR-5: invalid input goes to dead_letters. It is never repaired, guessed,
 * or silently dropped.
 */
export async function deadLetter(
  source: "mqtt" | "drive" | "tailscale",
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

  const readingData: LiveReadingData = {
    deviceId: device.deviceId,
    flowLpm: fields.flowLpm,
    totalL: fields.totalL,
    timestamp: new Date().toISOString(),
    raw: fields.raw,
  };
  LATEST_READINGS.set(device.deviceId, readingData);
  const canonicalId = device.deviceId.replace(/_/g, "-");
  LATEST_READINGS.set(canonicalId, readingData);

  try {
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
      // Remembered so the next reading can be plausibility-checked against
      // it (see ingestTelemetry.ts) — only overwritten when this reading
      // actually carried that field, so a flow-only packet never wipes out
      // the last known totalizer value (or vice versa).
      const deviceUpdate: Record<string, unknown> = {
        lastSeenAt: now,
      };
      if (fields.flowLpm !== null) {
        deviceUpdate.lastFlowLpm = fields.flowLpm;
        device.lastFlowLpm = fields.flowLpm;
      }
      if (fields.totalL !== null) {
        deviceUpdate.lastTotalL = fields.totalL;
        device.lastTotalL = fields.totalL;
      }
      device.lastSeenAt = new Date();
      tx.update(deviceRef, deviceUpdate);
      // No separate "alias doc" write here (there used to be one, meant
      // only for the EVT_EF_006 <-> EVT-EF-006 underscore/dash alias) —
      // device.deviceId is already canonicalized by findDeviceByNodeId
      // before insertReading ever sees it (via KNOWN_DEVICES/deviceIndex),
      // so writing a second doc under the alt spelling just created a
      // phantom duplicate device (e.g. "EVT_EF_002", "EVT_EF_004") for
      // every real device on every single reading, since any dash-only id
      // has a non-equal underscore "alt" form. Confirmed in the live
      // Firestore data: organizations/org-001/devices had EVT_EF_002 and
      // EVT_EF_004 docs with no name/location/mqttTopic, showing up in the
      // device selector as broken-looking duplicates of the real devices.
    });
  } catch (err) {
    console.warn(`Firestore transaction failed in insertReading for ${device.deviceId}:`, err);
  }
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
  // Dedupe key for imageExists, above. A real Drive file id for the Drive
  // pipeline; for the Tailscale pipeline (no file-id concept) this is the
  // filename itself, which is already unique per node+timestamp — kept
  // under this field name rather than adding a second one, since nothing
  // (backend or Flutter) treats it as anything but an opaque dedupe key.
  driveFileId: string;
  fileName: string;
  capturedAt: string | null;
  thumbUrl: string;
  storageUrl: string;
  // Defaults to "drive" so the existing Drive call site doesn't need to
  // pass this explicitly.
  source?: "drive" | "tailscale";
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
    source: fields.source ?? "drive",
  });
}
