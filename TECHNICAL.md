# EvaraFlow Dashboard: Technical Architecture Document

> Evaratech Pvt. Ltd. | Version 0.1 draft | 29 September 2026
> Part and section numbers refer to the full EvaraFlow documentation set (PRD.md, TECHNICAL.md, UIUX.md, EVARAFLOW_GROUND_TRUTH.md). The MQTT payload, topic names, and Drive naming convention are proposed defaults and must be confirmed against the real firmware and Drive setup before development starts.

---

## Part 0. Locked Product Goal

This section is the single source of truth for what the EvaraFlow Dashboard is. Every requirement, design decision, and line of code in this document set must be consistent with it. If a later section or an AI-generated suggestion conflicts with this section, this section wins.

### Goal Statement

**The EvaraFlow Dashboard lets a user select one EvaraFlow device and see everything about that device in one place: its current reading and past readings (from EMQX MQTT), and its latest image and past images (from Google Drive).**

### The Two Data Pipelines (never merged)

|  | Pipeline A: Readings | Pipeline B: Images |
|---|---|---|
| Source | EMQX MQTT broker | Google Drive folder |
| Content | Flow rate, totalizer, status, timestamps | Photos of the meter or deployment |
| Ingestion | Backend MQTT subscriber | Backend Drive sync worker |
| Stored in | Time-series table (readings) | Metadata table (images) plus cached thumbnails |
| Shown as | Current Reading, Historical Chart, Past Readings table | Latest Image, Image Gallery |
| Link between them | Both keyed by device_id only. Neither pipeline reads from or writes to the other. |  |

### What the Dashboard Is Not

- Not a multi-device wall of data. One device is selected at a time on the main dashboard.
- Not a place where numbers are estimated, smoothed silently, or invented. If data is missing, the UI says so.
- Not a place where an image is treated as a reading, or a reading is derived from an image, unless a future PRD explicitly adds that feature.
- Not a replacement for the EvaraOne platform in this phase. It is a focused EvaraFlow view built to be reusable for other Evaratech products later.

## Part 2. Technical Architecture Document

### 2.1 Architecture Summary

The browser never talks to EMQX or Google Drive directly. Two backend workers own the two pipelines. Both write to the database. The API serves the browser. A real-time channel pushes updates to any open device page.

#### Pipeline A: Readings

1. EvaraFlow device publishes JSON to an EMQX topic.
2. The backend MQTT subscriber (a shared subscription for horizontal scaling) receives the message.
3. The message is validated against the payload schema. Invalid messages go to a dead-letter table with the reason.
4. The reading is written to the readings table, idempotent on (device_id, device_ts).
5. The device's last_seen and current state are updated. Alert rules are evaluated.
6. An event is published to the real-time channel. Open device pages update within seconds.

#### Pipeline B: Images

Confirmed from real device firmware (2026-10-01, see Decision Log D-006): the device does not drop files into a watched folder. It actively **pushes** to a single shared Google Apps Script Web App over HTTPS, which writes to Drive on the device's behalf.

1. The device compresses the captured image (grayscale, resized, JPEG) and POSTs it as base64 JSON — `{filename, node_id, image}` — to the one shared Apps Script URL (not per-device).
2. Apps Script decodes the payload, writes the file to Drive, and returns `{status: "success", fileId}` to the device. This part already exists and is outside our backend.
3. **Primary ingestion (push):** the Apps Script is extended to also call our backend's `POST /api/ingest/drive-image` with `{node_id, filename, drive_file_id, captured_at}` right after a successful Drive write. The backend validates `node_id` against a known device (organization-scoped); on no match, the image is stored as Unassigned. It downloads the actual bytes from Drive via a read-only service account, creates a thumbnail and display copy in object storage, and writes the image row — idempotent on `drive_file_id`.
4. **Reconciliation poll (safety net):** because the Apps Script → backend call has no built-in retry, a low-frequency job (every 5–10 minutes) also polls the Drive Changes API against the same shared folder and backfills anything the push missed. This is a safety net, not the primary path — normal case latency is near-instant via the push, not the 30–60s a pure-poll design would add.
5. An event is published to the real-time channel on ingestion (from either path). Open device pages show a New Image badge.

This requires edit access to the existing Apps Script source to add step 3's callback — flagged as an action item, not something this backend can do unilaterally.

### 2.2 Recommended Technology Stack

These are recommendations. The rules in section 2.7 matter more than the specific tools. Updated 2026-10-01 (Decision Log D-013) to the Firebase-based stack actually chosen — full rationale and code in the companion backend plan artifact.

| Layer | Recommendation | Reason |
|---|---|---|
| Frontend | Flutter (already built) | Not React — the original generic recommendation predates the real implementation. |
| Ingestion (MQTT) | EMQX Rule Engine → HTTPS webhook → Railway-hosted Node/Express service (`server/`, see D-013) | Avoids both an always-open MQTT connection and the Blaze billing plan 2nd-gen Cloud Functions would have required. |
| Ingestion (Drive) | Same Railway service (HTTPS, called by the Apps Script addition) + a reconciliation sweep, not yet built | Matches the real push-based device flow (§2.1 Pipeline B). |
| Database | Firestore | Trades TimescaleDB's continuous aggregates for hand-rolled hourly/daily rollup documents — see the backend plan for the read-cost tradeoff at scale and the bucketing design that mitigates it. |
| Object storage | Firebase Storage | Cached images and thumbnails; same GCS foundation an S3-compatible bucket would have used. |
| Live updates | Firestore realtime listeners (`onSnapshot`) direct from Flutter | Replaces the custom SSE/Redis layer entirely — this is a genuine simplification, not just a platform swap. |
| Auth | Firebase Authentication + custom claims (role, org_id) | Firestore Security Rules read the claims directly, enforcing TR-11 org-scoping at the database layer. |
| Secrets | Google Cloud Secret Manager | MQTT device passwords, Apps Script webhook shared secret. |
| Observability | Cloud Logging + Cloud Monitoring | Native to the same GCP project Firebase runs on. |

### 2.3 Data Model

#### devices

| Column | Type | Notes |
|---|---|---|
| device_id | text, primary key | Human ID such as EF-001. Immutable. Also the `node_id` used in MQTT and Drive filenames — one identifier drives both pipelines. |
| org_id | uuid | Owner organization. |
| name, location | text | Editable labels. |
| mqtt_client_id | text | `EVT-{device_id}`, derivable but stored explicit. |
| mqtt_username | text | `device-{device_id}`, derivable but stored explicit. |
| mqtt_password_ref | text | Reference into a secret manager — **never** the raw password in this table. See §2.9. |
| mqtt_topic | text | `evaratech/v1/{device_id}/telemetry` — derivable but stored explicit. |
| drive_match_key | text | `{device_id}_` filename prefix — there is no per-device Drive folder or link (D-006). |
| expected_interval_s | int | Used for online or offline logic. |
| consumption_method | enum | totalizer or integrated_flow. Real firmware sends both `total_liters` and `flow_rate` on every message, so totalizer should be the default for new devices. |
| status | enum | online, offline, no_data (computed by backend). |
| last_seen_at | timestamptz | Time of last valid reading. |
| is_active, deleted_at | bool, timestamptz | Soft delete. |
| updated_by, updated_at | uuid, timestamptz | Audit. |

#### readings (time-series)

| Column | Type | Notes |
|---|---|---|
| device_id | text | Foreign key. |
| device_ts | timestamptz | **Open question (D-012):** real firmware sends no `ts`, so this is currently populated from `received_at`. Kept as a separate column so a future firmware update can populate it independently without a schema change. |
| received_at | timestamptz | Time the backend received it. The only timestamp the device pipeline can currently guarantee. |
| flow_lpm | numeric | Instantaneous flow, from `flow_rate`. |
| total_l | numeric, nullable | Totalizer value, from `total_liters`. |
| sensor_status | text | Not device-reported (no `status` field exists) — defaults to `"ok"` since firmware only publishes already-validated readings. |
| raw | jsonb | Original payload for audit. |

#### images

| Column | Type | Notes |
|---|---|---|
| id | uuid | Primary key. |
| device_id | text, nullable | Null means Unassigned. |
| drive_file_id | text, unique | Idempotency key. |
| file_name | text | Original name in Drive. |
| captured_at | timestamptz, nullable | Taken from filename or EXIF if available. |
| received_at | timestamptz | When the platform synced it. |
| storage_key, thumb_key | text | Cached copies. |
| sync_status | enum | pending, processing, synced, failed. |

#### Other tables

- alerts (id, device_id, type, severity, status, value, threshold, opened_at, acknowledged_by, resolved_at).
- device_latest (device_id, latest reading fields, latest_image_id). A small table that makes the dashboard load fast.
- dead_letters (source, payload, reason, created_at) for rejected MQTT messages and failed Drive files.
- users, organizations, memberships (role), audit_log.

### 2.4 MQTT Contract (Confirmed 2026-10-01 — see Decision Log D-004, D-005, D-010, D-011)

Confirmed directly from real device firmware. Two items below (QoS, transport security) are flagged open — see D-010/D-011 — and should not be treated as accepted until you decide.

| Item | Definition |
|---|---|
| Broker | `mqtt.evaratech.com`, port **1883 (plaintext — see D-010, open)**. |
| Topic | `evaratech/v1/{node_id}/telemetry` |
| Client ID | `EVT-{node_id}` (e.g. `EVT-EF-002`) |
| Username / password | `device-{node_id}` / a per-device secret. Device-side value only — never sent to the browser. |
| QoS | **0 (fire-and-forget — see D-011, open).** No LWT / status topic exists in the real firmware; online/offline is inferred purely from `last_seen_at` vs. `expected_interval_s` (TR-12), not from a retained LWT message as originally proposed. |
| Backend access | A dedicated backend user subscribed to `evaratech/v1/+/telemetry` (wildcard across all devices, shared subscription for horizontal scaling). Browsers have no MQTT credentials (TR-2, unchanged). |

Real telemetry payload — note what's **absent** compared to the original proposal: no `ts`, no `status`, no `fw`.

```json
{
  "node_id": "EVT-EF-002",
  "total_liters": 4820.0,
  "flow_rate": 12.4
}
```

Validation rules: `node_id` must match the topic and a known device. `total_liters` and `flow_rate` must be non-negative numbers when present (either may be `null`). Anything else is rejected to dead_letters. Messages are never silently repaired. Because there is no device-reported `ts`, `device_ts` is populated from `received_at` (see D-012, open) and `sensor_status` defaults to `"ok"` — the firmware only publishes after its own on-device detection/validation accepts a reading, so by the time a message reaches MQTT it already represents an accepted value, not a raw/unvalidated one.

### 2.5 Google Drive Contract (Confirmed 2026-10-01 — see Decision Log D-006)

Confirmed directly from real device firmware — the device pushes to Apps Script, it does not drop files into a watched folder.

| Item | Definition |
|---|---|
| Upload path | Device → HTTPS POST (base64 JSON) → single shared Google Apps Script Web App → Drive. The backend has no visibility into this leg; it only sees the result (see §2.1 Pipeline B). |
| Access | A Google Cloud service account with read-only access to the same Drive destination, used only to download bytes for thumbnailing after ingestion is triggered. No user OAuth in the path. |
| Folder layout | Single shared destination for the whole org — **not** one subfolder per device. Device identity lives entirely in the filename, not the folder. |
| Filename convention | `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg` — e.g. `EVT-EF-002_20261001_143522.jpg`. Underscore-separated, not the originally proposed `T`-separated ISO basic format. |
| Matching | Exact match on the `node_id` prefix. No fuzzy matching. No matching by image content. |
| Unmatched files | Stored as Unassigned and shown to Administrators for manual assignment. |
| Supported types | JPEG (device always sends JPEG; PNG support is speculative, kept for robustness). Other types recorded as failed with a reason. |
| Sync method | Primary: Apps Script → backend webhook push, near-instant. Safety net: Drive Changes API reconciliation poll every 5–10 minutes, catches anything the push missed. See §2.1 Pipeline B for the full sequence. |

### 2.6 API Outline

| Method | Path | Purpose |
|---|---|---|
| GET | /api/devices?search=&status= | List devices for the selector and All Devices page. |
| GET | /api/devices/{id} | Device details. |
| GET | /api/devices/{id}/current | Current reading, status, last seen, freshness flag. |
| GET | /api/devices/{id}/readings?from=&to=&bucket= | Historical readings, raw or aggregated. |
| GET | /api/devices/{id}/images?cursor= | Paginated images, newest first. |
| GET | /api/devices/{id}/images/latest | Latest image. |
| GET | /api/devices/{id}/events | SSE stream of new readings, status changes, and new images. |
| POST, PATCH, DELETE | /api/devices | Add, edit, and soft-delete devices. |
| GET, PATCH | /api/alerts | List alerts and update status. |
| GET, POST | /api/integrations/drive | Sync status, Sync Now. |
| GET | /api/integrations/mqtt | Connection status and last message time. |
| POST | `/ingest/drive-image` on the Railway service | Webhook called by the Google Apps Script after it writes a file to Drive. Body: `{fileId, fileName}` — `node_id` and `captured_at` are derived from `fileName` per D-006's `{node_id}_{YYYYMMDD}_{HHMMSS}.jpg` convention, not sent separately. See §2.1 Pipeline B, `server/src/routes/ingestDriveImage.ts`. Auth: `X-Webhook-Secret` header, not a user session (the caller is Apps Script, not the browser). |
| POST | `/ingest/telemetry` on the Railway service | Webhook called by the EMQX Rule Engine on every MQTT publish. Body: `{topic, payload}` (Rule Engine's own SELECT shape) — `payload` is the raw JSON string `{node_id, total_liters, flow_rate}` from D-005. See `server/src/routes/ingestTelemetry.ts`. Auth: `X-Webhook-Secret` header. |

### 2.7 Engineering Rules (Technical Rules TR)

| ID | Rule |
|---|---|
| TR-1 | Readings come only from EMQX. Images come only from Google Drive. No other source may populate either. |
| TR-2 | The browser never receives MQTT or Drive credentials, and never connects to EMQX or Drive. |
| TR-3 | Every reading and image row must trace back to a source message or Drive file ID. |
| TR-4 | Ingestion is idempotent: unique key (device_id, device_ts) for readings and drive_file_id for images. **Weakened by D-012** — since `device_ts` is currently `received_at`, two genuine readings arriving within the same second would collide under a strict unique constraint. Until D-012 is resolved, use a looser dedupe window (e.g. ignore a new reading only if an identical `(device_id, flow_lpm, total_l)` arrived within the last few seconds) rather than a hard unique index on `(device_id, device_ts)`. |
| TR-5 | Invalid input goes to dead_letters. It is never fixed, guessed, or dropped silently. |
| TR-6 | No mock or seed data in production code paths. Sample data lives only in a clearly separated development fixture. |
| TR-7 | Missing data is displayed as missing (empty state or gap). It is never interpolated, defaulted to zero, or estimated. |
| TR-8 | Device timestamps and server timestamps are both stored. The UI displays device time in the user's time zone (default Asia/Kolkata) and states the time zone. **Open conflict (D-012)**: real firmware sends no device timestamp, so until that's resolved this rule is only partially satisfiable — both columns exist but currently hold the same value. |
| TR-9 | Units are fixed in storage (L and L/min). Display conversion is a UI concern only. |
| TR-10 | Images are matched to devices by exact identifier only. |
| TR-11 | Every device-scoped query filters by org_id from the authenticated session. |
| TR-12 | Online or offline status is computed on the server as: offline if now minus last_seen exceeds 3 times expected_interval_s, or if the LWT status is offline. |
| TR-13 | Changes to the MQTT contract or Drive contract require a version bump and an update to this document before code changes. |

### 2.8 Error Handling and Resilience

- EMQX disconnect: subscriber reconnects with backoff and resumes with a persistent session. UI shows a Data feed interrupted banner after the stale threshold.
- Drive API error or quota: worker retries with backoff. Sync status in Settings shows Failed with the last error message.
- Duplicate delivery: ignored via unique keys.
- Out-of-order readings: stored by device_ts. Current Reading uses the greatest device_ts, not the latest arrival.
- Database unavailable: API returns a clear error. UI shows the error state. Workers buffer and retry.

### 2.9 Security and Access

- Role-based access: Viewer, Operator, Administrator, enforced in the API.
- Secrets in a secret manager, not in the repository or the client.
- EMQX ACLs restrict devices to their own topics. Rotate device credentials on decommission.
- Audit log for device edits, alert changes, integration changes, and user changes.

### 2.10 Deployment and Environments

- Environments: local development, staging with a test EMQX and a test Drive folder, production.
- Containerized services: API, MQTT worker, Drive worker, frontend, database, Redis.
- Health endpoints for each worker. Alert when ingestion lag exceeds 60 seconds.

## Part 4. Ground Truth and Anti-Hallucination Framework

The companion file EVARAFLOW_GROUND_TRUTH.md contains this framework in a form that can be pasted into any AI coding or design tool and kept in the repository root. This part explains how it works.

### 4.1 Why It Exists

AI tools drift. They invent fields that the firmware does not send, invent Drive behavior, fill empty charts with realistic fake numbers, and quietly change scope. The ground truth file gives the AI a fixed goal, fixed data sources, explicit correct and incorrect directions, and a rule to ask when unsure.

### 4.2 Structure of the Ground Truth File

1. Goal statement (identical to Part 0).
2. Source-of-truth table: what comes from where, and what may never be assumed.
3. Correct direction and wrong direction pairs.
4. Non-negotiable rules (technical rules TR-1 to TR-13 in short form).
5. Definition of done for every task.
6. Uncertainty protocol: how the AI must ask instead of guessing.
7. Decision log: a running list of confirmed contract decisions, so the AI does not re-decide them.

### 4.3 How to Use It

- Place the file at the repository root and in the AI tool's project instructions or system prompt.
- Begin every new AI session with: Read EVARAFLOW_GROUND_TRUTH.md first and confirm the goal in one sentence.
- When the real firmware payload or Drive convention is confirmed, update the Decision Log in the file and Part 2 of this document together.
- Review AI output against the Definition of Done checklist before merging.

## Part 5. Test and Acceptance Plan

### 5.1 Acceptance Tests for the Core Promise

| ID | Scenario | Expected result |
|---|---|---|
| AT-1 | Select a device with data and images. | Header, Current Reading, Latest Image, chart, table, and gallery show data for that device only. |
| AT-2 | Publish a new MQTT message for the selected device. | Current Reading and Last Updated change within 3 seconds. Table and chart include it. |
| AT-3 | Publish for a different device while one is selected. | Selected view does not change. |
| AT-4 | Upload EF-001_...jpg to the Drive folder. | Image appears in EF-001 gallery within 2 minutes with New Image badge. |
| AT-5 | Upload a file whose name matches no device. | Appears in Unassigned Images for Administrators. Not shown on any device. |
| AT-6 | Publish the same MQTT message twice. | One reading row. |
| AT-7 | Sync the same Drive file twice. | One image row. |
| AT-8 | Switch device quickly several times. | Final view matches the last selected device. No mixed data. |
| AT-9 | Stop a device from publishing beyond 3 intervals. | Status becomes Offline. Alert created. Current Reading shows Stale. |
| AT-10 | Publish an invalid payload. | Stored in dead_letters. Not shown in the UI. |
| AT-11 | Open a device with no images and one with no readings. | Correct empty states from section 3.6. |
| AT-12 | Disconnect EMQX. | Dashboard shows last known data with clear staleness message. No fabricated values. |
| AT-13 | Viewer opens a device from another organization by URL. | Access denied message. No data leaked. |

### 5.2 Other Testing

- Unit tests for payload validation, status computation, and consumption calculation.
- Integration tests with a test EMQX broker and a test Drive folder.
- Load test: 500 devices publishing every 10 seconds, ingestion lag under 5 seconds.
- Accessibility check with keyboard-only navigation and a screen reader.
- Visual check on desktop, tablet, and mobile widths.

## Part 8. Appendix

### 8.1 Glossary

| Term | Meaning |
|---|---|
| Device ID | Unique identifier of an EvaraFlow device, for example EF-001. |
| Reading | One telemetry record received over MQTT. |
| Totalizer | Cumulative volume counter reported by the device. |
| LWT | Last Will and Testament: MQTT message the broker publishes if the device disconnects unexpectedly. |
| Stale | Data older than the allowed threshold for that device. |
| Unassigned image | Drive image that could not be matched to a device by exact identifier. |
| Dead letter | A rejected message or file stored with a reason for later review. |
| Idempotent | Processing the same input twice has the same result as processing it once. |

### 8.2 Document Control

| Item | Detail |
|---|---|
| Product | EvaraFlow Dashboard (Evaratech Pvt. Ltd.) |
| Document set version | 0.1 draft for review |
| Date | 29 September 2026 |
| Status | Assumptions in section 1.8 pending confirmation |
| Companion file | EVARAFLOW_GROUND_TRUTH.md |
