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
  // The interesting case — flipping to offline after silence — is handled
  // by a separate scheduled function (not yet built) that sweeps all
  // devices and checks last_seen_at against expected_interval_s; a single
  // incoming reading can only ever prove "online," never "offline."
  await deviceRef.update({
    status: "online",
    statusUpdatedAt: FieldValue.serverTimestamp(),
  });

  // Extension point: no-flow / high-flow threshold checks go here once
  // D-008's thresholds are confirmed rather than assumed.
}
