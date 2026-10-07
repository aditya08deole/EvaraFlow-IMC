/**
 * TR-12: online/offline status is computed on the server, never the
 * browser. Offline when now - last_seen exceeds 3x expected_interval_s.
 *
 * The original LWT-based offline signal (D-007/TR-12) doesn't apply here —
 * the real firmware publishes no status/LWT topic at all (D-005) — so this
 * is purely interval-based.
 *
 * Alert evaluation (no-flow / high-flow / offline, PRD FR-G1) is stubbed as
 * a single extension point rather than fully built out here — the
 * thresholds and alert-document shape need the same real-firmware-driven
 * confirmation the MQTT/Drive contracts got before this should write real
 * alert rows (see EVARAFLOW_GROUND_TRUTH.md D-008, still Proposed).
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { DeviceRef } from "./db";

export async function recomputeStatusAndAlerts(
  device: DeviceRef
): Promise<void> {
  const db = getFirestore();
  const deviceRef = db
    .collection("organizations")
    .doc(device.orgId)
    .collection("devices")
    .doc(device.deviceId);

  // A reading just arrived, so by definition the device is online right now.
  // The interesting case — flipping to offline after silence — can only
  // ever be proven by the absence of a reading, never by one arriving, so
  // it's handled separately by sweepOfflineDevices below.
  await deviceRef.update({
    status: "online",
    statusUpdatedAt: FieldValue.serverTimestamp(),
  });

  // Extension point: no-flow / high-flow threshold checks go here once
  // D-008's thresholds are confirmed rather than assumed.
}

/**
 * Runs on a short interval from index.ts (no Cloud Scheduler on Railway,
 * so a plain setInterval in this always-on process stands in for one) and
 * flips any device whose last_seen_at has gone stale from "online" to
 * "offline" — the one case recomputeStatusAndAlerts above can never prove
 * on its own, since a reading arriving only ever proves the opposite.
 * lib/services/api_service.dart's Device.isStale check already hides this
 * same staleness client-side at read time regardless, but without this
 * sweep the stored `status` field itself stays wrong indefinitely for
 * anything reading Firestore directly (the Data Quality panel, a future
 * integration, a raw query) — this makes the source of truth correct, not
 * just its display.
 */
export async function sweepOfflineDevices(): Promise<void> {
  const db = getFirestore();
  let snap;
  try {
    snap = await db
      .collectionGroup("devices")
      .where("status", "==", "online")
      .get();
  } catch (err) {
    // Gracefully ignore Firestore quota limits
    return;
  }

  const now = Date.now();
  let flipped = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const lastSeenAt = (data.lastSeenAt as { toDate?: () => Date } | undefined)?.toDate?.();
    if (!lastSeenAt) continue;
    const expectedIntervalSeconds = (data.expectedIntervalSeconds as number | undefined) ?? 300;
    const staleAfterMs = expectedIntervalSeconds * 3 * 1000;
    if (now - lastSeenAt.getTime() > staleAfterMs) {
      await doc.ref.update({
        status: "offline",
        statusUpdatedAt: FieldValue.serverTimestamp(),
      });
      flipped++;
    }
  }
  if (flipped > 0) {
    console.log(`sweepOfflineDevices: flipped ${flipped} device(s) to offline`);
  }
}
