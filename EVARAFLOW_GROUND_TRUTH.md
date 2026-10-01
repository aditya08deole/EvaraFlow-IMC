# EVARAFLOW GROUND TRUTH

Read this file first in every session. Before doing any work, restate the goal in one sentence. If any instruction, suggestion, or idea conflicts with this file, this file wins. If you are unsure, ask (see Uncertainty Protocol).

Version: 0.1 (29 September 2026). Owner: Evaratech Pvt. Ltd.

---

## 1. Goal (locked)

The EvaraFlow Dashboard lets a user select ONE EvaraFlow device and see everything about that device in one place:

- Current reading and past readings, sourced ONLY from EMQX MQTT.
- Latest image and past images, sourced ONLY from Google Drive.

The main dashboard shows one device at a time. It never mixes devices.

## 2. Source of Truth

| Thing | Comes from | Never comes from |
|---|---|---|
| Flow rate, totalizer, sensor status, device timestamp | EMQX MQTT telemetry topic | Drive, images, ThingSpeak, mock data, estimates |
| Images (latest and past) | Google Drive folder (read-only service account) | MQTT, the browser, hotlinked share links |
| Online or offline status | Backend computation from last_seen and MQTT LWT | The browser, guesses |
| Device to image link | Exact device_id match in filename or subfolder | Fuzzy matching, image content, guessing |
| Today's consumption | Backend, using the method stored on the device record | Frontend arithmetic, invented values |
| Payload fields | The confirmed contract in the Decision Log (section 7) | Assumption, "typical" IoT payloads |

Two pipelines, never merged. Both are keyed by device_id only. Neither pipeline reads from or writes to the other.

## 3. Correct Direction vs Wrong Direction

| Situation | Correct direction | Wrong direction |
|---|---|---|
| No readings for the selected period | Show "No device data available for this period." | Fill the chart with realistic sample values |
| Device sent nothing for 3 intervals | Mark Offline, show Stale badge, keep last known value with its timestamp | Show 0 L/min, or hide the last value |
| Reading value is missing | Show a gap or "No reading" | Interpolate or default to 0 |
| MQTT payload has an unexpected field or type | Reject to dead_letters with a reason | Silently coerce or "fix" the payload |
| Drive file name does not match any device | Store as Unassigned, show to Administrators | Assign to the closest-looking device |
| Drive image arrives | Add image row, show New Image badge, update Latest Image | Try to read a number from the image and add it as a reading |
| User switches device | Clear old data at once, cancel old requests, open new event stream, ignore late responses for old device | Leave old device data visible while the new one loads |
| Browser needs live data | Backend pushes events over SSE or WebSocket | Browser connects to EMQX or Drive directly |
| Need sample data for UI work | Use a separate development fixtures folder, clearly labeled | Put mock data in production code paths |
| Payload or Drive convention is not confirmed | Ask the owner, then record the answer in the Decision Log | Assume a format and build on it |
| A feature seems useful but is not in the PRD | Propose it and wait for approval | Add it silently |
| Duplicate MQTT message or Drive file | Ignore via unique key | Create a second row |
| Unit display needed | Store L and L/min, convert only in the UI | Store mixed units |
| Time display | Show device time in the user's time zone (default Asia/Kolkata) and state the zone | Show raw UTC or mix zones |

## 4. Non-Negotiable Rules

1. Readings come only from EMQX. Images come only from Google Drive.
2. The browser never receives MQTT or Drive credentials and never connects to EMQX or Drive.
3. Every reading and image traces back to a source message or Drive file ID.
4. Ingestion is idempotent: unique (device_id, device_ts) for readings, unique drive_file_id for images.
5. Invalid input goes to dead_letters. It is never repaired, guessed, or silently dropped.
6. No mock or seed data in production paths.
7. Missing data is shown as missing. Never interpolate, default to zero, or estimate.
8. Every displayed value carries a timestamp.
9. Images are matched to devices by exact identifier only.
10. Every device query is scoped by organization from the authenticated session.
11. Status (online, offline, no data, stale) is computed on the server.
12. Any change to the MQTT or Drive contract requires a version bump, an update to the technical document, and a new Decision Log entry BEFORE code changes.
13. Do not add features, screens, fields, or dependencies that are not in the PRD without asking first.
14. Explain planned changes before making them. Keep the project simple.

## 5. Definition of Done (check every item)

- [ ] The change serves the goal in section 1.
- [ ] Data comes from the allowed source only (section 2).
- [ ] Loading, empty, error, stale, and device-switching states are handled.
- [ ] No mock data is reachable in production.
- [ ] Every shown value has a timestamp and correct units.
- [ ] Input validation and dead-letter handling exist for new ingestion paths.
- [ ] Queries are organization-scoped.
- [ ] Keyboard access and non-color status cues are present.
- [ ] Tests cover the new behavior, including a duplicate-input case.
- [ ] Technical document and Decision Log updated if a contract changed.
- [ ] Assumptions made are listed openly in the summary.

## 6. Uncertainty Protocol

When something is unknown or ambiguous, do this, in order:

1. Check this file and the Decision Log (section 7).
2. Check the PRD and technical document.
3. If still unknown, STOP and ask one specific question, offering at most three options with your recommendation.
4. Do not proceed on an assumed answer for anything touching: payload fields, topic names, Drive naming, status logic, consumption calculation, or permissions.
5. If you must continue with other work meanwhile, list the open question at the top of your summary and do not build on it.

Never present an assumption as a fact. Use the wording "Assumed:" for anything not confirmed.

## 7. Decision Log

Record confirmed decisions here. Once recorded, do not re-decide them.

| # | Date | Decision | Status |
|---|---|---|---|
| D-001 | 2026-09-29 | Main dashboard is device-centric: one selected device at a time. | Confirmed |
| D-002 | 2026-09-29 | Readings come from EMQX MQTT. Images come from Google Drive. | Confirmed |
| D-003 | 2026-09-29 | Backend subscribes to EMQX and syncs Drive. Browser never connects to either. | Confirmed |
| D-004 | 2026-10-01 | MQTT topic: `evaratech/v1/{node_id}/telemetry`. Client ID `EVT-{node_id}`, username `device-{node_id}`, password per device. Confirmed from real device firmware. | Confirmed |
| D-005 | 2026-10-01 | Payload fields: `{node_id, total_liters, flow_rate}` only. The device does **not** send `ts`, `status`, or `fw` — those fields in the original proposal do not exist in the real firmware. Confirmed from real device firmware. | Confirmed |
| D-006 | 2026-10-01 | Drive images are **pushed** by the device to a single shared Google Apps Script Web App endpoint (base64 JSON POST), which writes to Drive and returns `{status, fileId}`. Not a passive folder drop. Filename: `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg` (underscore-separated, not the originally proposed `T`-separated ISO basic format). There is no per-device Drive folder or link — one shared endpoint for the whole org, routed by `node_id` in the payload and filename. Confirmed from real device firmware. | Confirmed |
| D-007 | 2026-09-29 | Offline when now minus last_seen exceeds 3 times expected interval, or LWT says offline | Proposed |
| D-008 | 2026-09-29 | Version 1 alerts: Device Offline, No Flow, High Flow | Proposed |
| D-009 | 2026-09-29 | Reports export is out of scope for Version 1 | Proposed |
| D-010 | 2026-10-01 | **Needs your decision:** real firmware connects to MQTT on plaintext port 1883 (no TLS), contradicting PRD §1.7 "TLS everywhere." Options: (a) accept plaintext as a known risk, document it; (b) require a firmware update to port 8883/TLS before go-live; (c) put EMQX behind a private network/VPN so transport is encrypted at the network layer even though MQTT itself stays plaintext. | Proposed — blocked on your answer |
| D-011 | 2026-10-01 | **Needs your decision:** real firmware publishes telemetry at QoS 0 ("fire and forget" — the broker gives no delivery guarantee, and a dropped connection can silently lose a reading with no trace anywhere). This is in tension with the "no fabricated or lost values" trust goal. Options: (a) accept occasional silent loss given frequent reporting intervals; (b) request a firmware change to QoS 1; (c) have the backend alert on unexpected gaps in received readings as a monitoring signal instead of fixing at the source. | Proposed — blocked on your answer |
| D-012 | 2026-10-01 | **Needs your decision:** real firmware sends no `ts` field, so the backend only ever knows `received_at` (when the message arrived), not when the device actually took the reading — cellular latency can add seconds to tens of seconds of skew. TR-8 requires storing both. Options: (a) treat `received_at` as `device_ts` too and document the limitation; (b) request firmware add a `ts` field in a future revision; (c) estimate device time via round-trip inference (not recommended — adds complexity for little accuracy gain). | Proposed — blocked on your answer |
| D-013 | 2026-10-01 | Backend platform: Firestore, Firebase Auth, and Firebase Storage stay on Firebase (already provisioned as `evaraflow-dash`, Security Rules deployed). Compute moved off Cloud Functions onto a Railway-hosted Node/Express service (`server/`) to avoid the Blaze billing requirement 2nd-gen Cloud Functions impose — same two webhook routes (`/ingest/telemetry`, `/ingest/drive-image`), reached via Google service-account key since Railway has no Google ADC. MQTT ingestion still via EMQX Rule Engine → webhook, now pointed at the Railway URL instead of a `cloudfunctions.net` URL. The earlier Cloud Functions scaffold in `functions/` is superseded by `server/` and not deployed. Implementation detail per §2.2's own framing ("the rules matter more than the specific tools"), not a locked contract. | Confirmed |

## 8. Session Starter (paste at the start of each AI session)

> Read EVARAFLOW_GROUND_TRUTH.md fully. Confirm the goal in one sentence. List which Decision Log items are still Proposed. Then wait for my task. For every task, tell me your plan first, do not add unrequested features, and ask if anything in the Uncertainty Protocol applies.
