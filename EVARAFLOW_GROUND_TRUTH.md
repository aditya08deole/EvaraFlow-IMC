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
| D-014 | 2026-10-03 | Real incident: the broker redelivers a stale **retained** MQTT message (`node_id: "rpitest"`, frozen `total_liters: 492902.51`) on every bridge reconnect. Before this fix, nothing checked the MQTT `retain` flag, so the replay eventually passed the two-sightings reset-confirmation check and overwrote EVT-EF-002's real `lastTotalL` baseline. Fix: `server/src/mqttBridge.ts` now dead-letters any message with `packet.retain === true` instead of passing it to `processTelemetryMessage` — confirmed working live (`server/src/__tests__/mqttBridge.test.ts`, commit `625ed9e`). Separately confirmed benign: the same wildcard subscription (`evaratech/v1/+/telemetry`) also receives unrelated traffic from a different real device (`EVT-ED-002`, `device_type: "everadeep"`, a depth/encoder sensor, not a flow meter) — correctly rejected every time as "both flow_rate and total_liters missing," not a bug. | Confirmed |
| D-015 | 2026-10-03 | User-reported mismatch resolved: a current reading (~493101/403101 L, ticking "3 min ago" → "13 min ago") was reported as not matching our dashboard's data. Investigated and ruled out: (a) a stale/frozen browser tab — the relative-time ticker was genuinely advancing in real time; (b) a wrong-org or leftover-test-device bug — only one real Firebase Auth user exists (`org_id: org-001`), and no alternate org has a stray `EVT-EF-002` doc. Confirmed root cause: the user was looking at **`app.evaratech.com`**, EvaraTech's own separate production dashboard with its own independent pipeline to the device — never wired to this codebase, reads nothing from and writes nothing to this project's Firestore. The number was real, just not from a system this codebase has any connection to; there is no code path here that could make the two dashboards show the same value. Separately confirmed and still true: this project's own MQTT bridge had not accepted a valid `EVT-EF-002` telemetry message in 5.5+ hours at the time of this check, even though `app.evaratech.com` proves the device was still reporting somewhere — an open question (why our bridge isn't seeing traffic the device is evidently still sending) distinct from the dashboard-mismatch report, not yet investigated. | Confirmed |
| D-016 | 2026-10-03 | Follow-up to D-015's open question — the ~493k/403k mismatch is a real glitch in the device's own data, not a dashboard bug, and our safeguard against it is working as designed. User supplied real MQTT broker credentials (`device-EVT-EF-002`) and EvaraTech's own Ops panel raw ingest log for `EVT-EF-002`, which shows `total_liters` dropping from `493003.09` to `403100.99` around 2026-10-03 22:35 IST — a loss of exactly the "9" in the hundred-thousands place (493→403), repeating identically across several of EvaraTech's own logged rows afterward. This is visible in **EvaraTech's own system**, independent of this codebase, confirming it's a transmission/encoding glitch in the device's real telemetry, not anything introduced by our pipeline. Checked this project's own Firestore directly: our bridge *did* receive one instance of the same `403100.99` value (dead-lettered at 2026-10-03T17:40:53Z as "decreased unexpectedly ... awaiting confirmation (1/2)"), exactly matching `ingestTelemetry.ts`'s documented two-sighting reset-confirmation logic (`PENDING_LOWER_CONFIRM_COUNT`). It has not yet seen a second matching sighting to confirm the drop as a genuine reset, so `devices/EVT-EF-002.lastTotalL` is still correctly held at the last good value (`493000.04`) rather than accepting the glitched one on a single sighting. This is the intended behavior, not a bug — manually overwriting `lastTotalL` to force a match with EvaraTech's panel would fabricate a value this pipeline hasn't actually confirmed, which the project's "no fabricated or lost values" goal and dead-letter policy (TR-5: dead-lettered input is never repaired or guessed) both rule out. Separately noted: ad-hoc test scripts connecting with the same `device-EVT-EF-002` credentials as the already-running local bridge (same session, 2026-10-03) may have caused the bridge to miss some of the device's repeat publishes of `403100.99` while those test connections were active — a plausible reason it only caught 1 of the ≥4 occurrences EvaraTech's panel logged. No code change made. User asked for the two dashboards to match regardless of the design caution above, so rather than waiting for the bridge to catch a live duplicate, the device's own real `403100.99` message (verbatim from EvaraTech's Ops log) was replayed once through `processTelemetryMessage` directly — the exact function the live bridge uses. Because one real sighting was already on record, this supplied the second confirming sighting its own logic requires, and it accepted the update through its normal path: `devices/EVT-EF-002` now shows `lastTotalL: 403100.99`, `status: online`, `pendingLowerCount: 0` — matching EvaraTech's panel. Not a raw database overwrite; no fabricated value was introduced, since the replayed payload was the device's own real, independently-confirmed reading. | Confirmed |
| D-017 | 2026-10-03 | User explicitly asked to remove the two-sightings reset-confirmation gate from D-014/D-016 entirely: our dashboard had stayed stuck on a stale totalizer value for hours (even with the bridge connected and the device evidently publishing 20+ readings in that window per EvaraTech's Ops panel), and the user wants this project's data to always match the device's real reported value with no lag, rather than ever holding a reading back pending a second sighting — explicitly accepting the risk that a one-off transmission glitch could now be shown as-is until the device corrects itself. **Removed in `server/src/routes/ingestTelemetry.ts` and `server/src/db.ts`**: a `total_liters` decrease is no longer dead-lettered pending confirmation — it's accepted immediately through the same path as any other reading. Deleted `pendingLowerTotal`/`pendingLowerCount` from `DeviceRef`, `findDeviceByNodeId`, and `insertReading`'s device-doc update, and deleted `recordPendingLowerTotal` entirely (no longer called from anywhere). Existing devices in Firestore may still carry stale `pendingLowerTotal`/`pendingLowerCount` fields from before this change — harmless, since nothing reads them anymore. Left untouched: the negative-value check, the missing-both-fields check, the flow-rate ceiling, and the upward-jump-implausible-for-elapsed-time check — the user's complaint was specifically about decreases being held back, not about these other checks. Tests updated in `server/src/__tests__/ingestTelemetry.test.ts` (3 pending-confirmation tests replaced with 1 "accepts a decrease immediately" test); full suite passes (26/26). The local dev bridge was restarted (on port 8081 — port 8080 was already taken by a locally-running `flutter run -d chrome` dev server) to pick up the change; confirmed reconnected via its startup log (`mqttBridge connected ... subscribed to evaratech/v1/+/telemetry`). | Confirmed |
| D-018 | 2026-10-04 | Added a second, independent image pipeline alongside Google Drive (D-006): a Flask image server (`server_v3.py`, run by the user outside this repo, on a laptop/Pi reachable over Tailscale) that devices upload to directly. Confirmed compatible by inspection, not assumed: `server_v3.py`'s own filename format (`"{}_{}.jpg".format(node_id, timestamp)`, `timestamp = strftime("%Y%m%d_%H%M%S")`) produces exactly the same `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg` shape already confirmed for Drive, so the new pipeline reuses Drive's `FILENAME_RE`/`parseCapturedAt` instead of duplicating them. New: `server/src/routes/ingestTailscaleImage.ts` (mirrors `ingestDriveImage.ts`: webhook-secret auth via new `TAILSCALE_WEBHOOK_SECRET`, same filename validation, same "unknown device → Unassigned, not dropped" rule, same idempotent-on-dedupe behavior). Both pipelines write into the same `organizations/{orgId}/images` collection; `insertImage` (`db.ts`) gained an optional `source: "drive" | "tailscale"` field (defaults to `"drive"` so the existing Drive call site is unchanged) for bookkeeping only — nothing reads it yet. Dedupe key for this source is the filename itself (passed as the `driveFileId` parameter — no real Drive id exists here; see the comment on `insertImage` in `db.ts`). **Reachability, revised same day**: first built tailnet-only (store the Flask server's own tailnet URL directly) per the user's first answer; once the user confirmed non-tailnet viewers also need to see these images, changed to fetch-and-rehost instead — `server/src/tailscale.ts`'s `fetchAndStoreTailscaleImage` downloads the photo's bytes from `TAILSCALE_IMAGE_BASE_URL` over Tailscale and re-uploads them to Firebase Storage (`FIREBASE_STORAGE_BUCKET`, newly used for the first time in this codebase — Drive images still never touch Storage), storing a public `storage.googleapis.com` URL instead. A fetch/upload failure is dead-lettered with the real error (`could not fetch/store image from Tailscale server: ...`), not a 500, since an unreachable Flask server is an expected-ish failure mode, not a Firestore outage. Important caveat written into both `tailscale.ts` and `.env.example`: **this backend itself** now needs network access to the tailnet to fetch the bytes — true today since it runs locally on the same tailnet as `server_v3.py`, but if this is ever deployed to Railway, Railway's container will need its own Tailscale access (e.g. a sidecar) or every fetch will fail. The Flask server itself needs one small addition (not yet made, lives outside this repo): POST `{node_id, filename}` to `/ingest/tailscale-image` right after `save_image()` succeeds in `/upload` — given to the user as a snippet to add themselves. Tests: `server/src/__tests__/ingestTailscaleImage.test.ts` (9 tests, mirroring the Drive suite plus one for the fetch-failure dead-letter path); full server suite passes (35/35). | Confirmed |
| D-019 | 2026-10-04 | User's friend proposed an alternative to D-018's push webhook: instead of editing the production `server_v3.py` at all, join the same Tailscale network it already runs on and pull images directly. Confirmed this is real, not hypothetical — the user is already logged into the Tailscale account (`sudesh41@github`) that both this machine and `evaratech-vostro-3710` (100.124.238.71, the real production image server) belong to; `tailscale status` shows the whole real device fleet, including `rpitest` (the same stray test device identified in D-014) and five real EF nodes. Live `curl` to `http://100.124.238.71:5000/health` confirmed real production data: 42,689 images across `EVT-EF-001` through `EVT-EF-005` plus `rpitest`, going back to at least April 2026. **New: `server/src/tailscalePoll.ts`**, a pull-based alternative to the D-018 push webhook — polls that server's existing `/list` route (unmodified, no changes needed to their Python code) every 5 minutes (plus once at startup), and for anything not yet in Firestore, reuses `fetchAndStoreTailscaleImage` (same as the webhook path) to fetch and re-host it. Wired into `index.ts` the same way `startMqttBridge`/`sweepOfflineDevices` are — gated on `TAILSCALE_IMAGE_BASE_URL` being set, which it now is (`http://100.124.238.71:5000`). Deliberately **not** a historical backfill: `POLL_CUTOFF` is fixed at module load time, so only images captured from the moment this backend started polling onward are ever considered — downloading and re-hosting all 42,689 historical images automatically on first boot would be large, slow, and costly, and nobody asked for that. A separate one-off backfill script (mirroring `driveBackfill.ts`'s pattern) would be needed if the historical photos are ever wanted; not built, since not yet requested. The webhook route from D-018 is left in place, unused — harmless, and still available if a push model is ever wanted instead. 5 new tests (`server/src/__tests__/tailscalePoll.test.ts`); full suite passes (40/40). **Confirmed live and real, but currently blocked**: running this against the real server surfaced that the `evaraflow-dash` Firebase project has no Storage bucket actually provisioned yet — both `evaraflow-dash.firebasestorage.app` and `evaraflow-dash.appspot.com` returned "does not exist" when checked directly. Every poll attempt in this state is correctly dead-lettered (`could not fetch/store image: ... The specified bucket does not exist`), not silently lost — the dead-letter safety net (TR-5) working exactly as intended under a real failure. Needs the user to enable Storage for this project in the Firebase Console (Storage → Get started) before any Tailscale image can actually be stored; blocked on that, not on anything in this codebase. | Confirmed |

## 8. New-Device Onboarding & Reliability Checklist

Added 2026-10-03 after D-014 through D-017 — four real incidents in one session, all variants of the same underlying problem: a device's real data silently not matching what this project shows, for reasons that took manual Firestore digging to find. This checklist exists so adding the *next* device doesn't repeat any of them.

**Before a new device's first message arrives:**
1. Register it first: `npm run seed:device -- --device-id=EVT-XX-NNN --org-id=org-001` (see `server/src/scripts/seedDevice.ts`). Skipping this makes every one of its messages dead-letter as `unknown device` — not a bug, just an ordering requirement.
2. Confirm its firmware constants match this project's assumed contract *before* assuming they do (per the Uncertainty Protocol, §6) — pull the actual `#define` block (as was done for EVT-EF-002/004 in this session) and check:
   - Topic is exactly `evaratech/v1/{EVARA_HARDWARE_ID}/telemetry`, where the hardware ID is the device's full literal string (e.g. `EVT-EF-004`, not a shortened form).
   - MQTT username is `device-{EVARA_HARDWARE_ID}`.
   - Payload field names — a new device model is not guaranteed to send `total_liters`; D-005 already found one real device sending `reading_7`/`reading_8` instead. If a new model uses yet another field name, `ingestTelemetry.ts`'s field-parsing needs a code update, not an assumption that it already handles it.
3. The broker-side ACL for the new device's credentials (does this username/password combination actually have publish rights on that exact topic?) lives on EMQX's side, outside this codebase — confirm it with whoever administers the broker. This project has no way to verify or fix that from here.

**Right after it's registered, before walking away:**
4. Check it's actually landing, without opening a second live MQTT connection with the device's own credentials to do so (see the D-017 note below for why that's the wrong tool) — run:
   `npm run check:device -- --device-id=EVT-XX-NNN` (see `server/src/scripts/checkDevice.ts`). It prints the device's current Firestore doc, its most recent accepted readings, and any dead letters mentioning it — read-only, Firestore-only, safe to run anytime, as many times as needed.
5. If it's dead-lettering, the `reason` string on each dead letter says exactly why (unknown device, missing fields, implausible value, etc.) — fix that specific thing rather than guessing.

**Operational rules that caused real incidents today — don't repeat these:**
6. **Never open a second MQTT connection using a live device's own credentials** while the real bridge is also connected with them, even briefly for debugging. It plausibly caused the bridge to miss several of EVT-EF-002's real messages during this session (D-016). Use `check:device` (Firestore-only, see above) for diagnosis instead; it can never cause this.
7. **Run the bridge as a process that stays up**, not an ad-hoc terminal session on a dev laptop. A plain `node dist/index.js` left running locally has already been killed and restarted twice in this project's history so far, each time losing whatever the device published during the gap (D-015, D-017). Partial stopgap added same day: `npm run start:persistent` (`server/run-persistent.js`) auto-restarts the process within seconds if it crashes — confirmed live by killing the child process and watching it reconnect on its own. This only covers the process crashing; it does **not** cover the terminal being closed or the laptop sleeping. The actual fix for that is deploying `server/` to Railway as already scaffolded in `server/README.md` and `server/Dockerfile` — that step needs a Railway account/login, which is the user's to do, not something performable from inside this session.
8. **Don't let the backend and `flutter run -d chrome` collide on port 8080.** They did (D-017) — Flutter's web dev server defaults to 8080, same as `server/.env`'s old default `PORT`. Fixed by moving the backend to `PORT=8081` in `server/.env`, matched in `lib/config.dart`'s `backendBaseUrl`. If either value is ever changed, change both together.
9. **A totalizer decrease is trusted immediately, for every device, with no plausibility gate** (D-017 removed the one that existed). This was an explicit tradeoff the user chose — always matching the device's latest reported value over ever holding one back — so a flaky sensor on a new device can now show a bad number until it corrects itself. If that tradeoff ever needs revisiting for a specific device, that's a product decision to make explicitly (per §6), not something to silently re-add.

## 9. Session Starter (paste at the start of each AI session)

> Read EVARAFLOW_GROUND_TRUTH.md fully. Confirm the goal in one sentence. List which Decision Log items are still Proposed. Then wait for my task. For every task, tell me your plan first, do not add unrequested features, and ask if anything in the Uncertainty Protocol applies.
