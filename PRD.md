# EvaraFlow Dashboard: Product Requirements Document (PRD)

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

## Part 1. Product Requirements Document (PRD)

### 1.1 Overview

EvaraFlow devices measure and report water flow. Today their readings and their photos arrive through different channels and are seen in different places. Users must jump between tools to answer a simple question: what is this device doing now, and what has it done before. The EvaraFlow Dashboard removes that friction with a device-centric view.

### 1.2 Problem Statement

- Readings arrive over MQTT and are not easy for non-technical users to view.
- Images arrive in Google Drive and are disconnected from the readings of the same device.
- Multi-device views are cluttered and make it hard to focus on one installation.

### 1.3 Objectives and Success Metrics

| Objective | Measure of success |
|---|---|
| Fast understanding of one device | A user selects a device and sees current reading, status, and latest image within 3 seconds on a normal connection. |
| Trustworthy data | Every displayed value carries a timestamp. No value is shown without a source record. Zero fabricated values in production. |
| Live feel | A new MQTT reading appears in the UI within 3 seconds of broker receipt while the device page is open. |
| Image freshness | A new Drive image appears in the device gallery within 2 minutes of upload. |
| Scale readiness | Device selector remains usable with 500+ devices (search, recents). |

### 1.4 Users and Roles

| Role | Needs |
|---|---|
| Viewer | Select a device, view readings and images. Read-only. |
| Operator | Everything a Viewer can do, plus acknowledge alerts and edit device labels and location. |
| Administrator | Everything above, plus add or remove devices, manage users, configure Drive and MQTT integrations. |
| Evaratech internal | Support and diagnostics across organizations (phase 2). |

### 1.5 Scope

#### In scope for Version 1 (MVP)

- Main dashboard with device selector and selected-device view.
- Current Reading, Historical chart (Today, 7 Days, 30 Days, Custom), Past Readings table.
- Latest Image, View All Images gallery, image lightbox.
- All Devices page, Add Device, Edit Device.
- Profile and Settings (including Google Drive folder and MQTT status).
- Alerts page with three alert types: device offline, no flow when expected, high flow.
- Authentication and role-based access.

#### Out of scope for Version 1

- Reports export (PDF, CSV, Excel). Planned for Version 1.1.
- Reading values extracted from images (OCR or digit recognition).
- Multi-product support (EvaraTank, EvaraTDS, and others). The architecture must allow it; the UI does not include it yet.
- Multi-device comparison analytics.
- Sending commands to devices.

### 1.6 Functional Requirements

#### A. Device Selection and Switching

| ID | Requirement |
|---|---|
| FR-A1 | The dashboard shall show a Device Selector at the top with search by device ID, name, and location. |
| FR-A2 | The selector shall show each device with its ID, name, and a status dot (online, offline, no data yet). |
| FR-A3 | The selector shall list Recent devices first, then all devices alphabetically. |
| FR-A4 | The selected device shall be stored in the URL (for example /dashboard?device=EF-001) so links and refresh preserve it. |
| FR-A5 | On first visit, the last-used device is selected. If none, the user's first device is selected. If the user has no devices, the empty state in section 3.6 is shown. |
| FR-A6 | Switching devices shall follow the behavior defined in section 3.7. |

#### B. Selected Device Overview

| ID | Requirement |
|---|---|
| FR-B1 | Show device ID, name, location, and status (Online, Offline, No data yet). |
| FR-B2 | Status is computed by the backend, never by the browser (see rule TR-12 in Part 2). |
| FR-B3 | Show Last Data Received as a relative time with the exact timestamp on hover. |

#### C. Current Reading (Pipeline A)

| ID | Requirement |
|---|---|
| FR-C1 | Show Current Flow (L/min), Today's Consumption (L), and Last Updated. |
| FR-C2 | Values update live when a new MQTT message arrives for the selected device. |
| FR-C3 | If the latest reading is older than the stale threshold, show it with a Stale badge. Never present a stale value as current. |
| FR-C4 | Today's Consumption is computed by the backend from the totalizer or from integrated flow. The calculation method is fixed per device and documented in the device record. |

#### D. Historical Readings (Pipeline A)

| ID | Requirement |
|---|---|
| FR-D1 | Chart of Flow Rate and Consumption against time for the selected device. |
| FR-D2 | Range switch: Today, 7 Days, 30 Days, Custom. |
| FR-D3 | Past Readings table with columns Date and Time, Flow, Consumption, Status. Paginated, newest first. |
| FR-D4 | For long ranges the backend returns aggregated buckets. The UI labels the aggregation (for example, 1-hour average). |
| FR-D5 | Gaps in data are shown as gaps, not interpolated lines. |

#### E. Latest Image and Gallery (Pipeline B)

| ID | Requirement |
|---|---|
| FR-E1 | Show the most recent image for the selected device with received time and Source: Google Drive. |
| FR-E2 | View All Images opens a gallery of the same device's images, newest first, with date and time on each. |
| FR-E3 | Clicking an image opens a large view with previous and next navigation. |
| FR-E4 | A new image arriving while the page is open shows a subtle New Image badge and updates the Latest Image. |
| FR-E5 | An image that cannot be matched to a device goes to an Unassigned Images list visible to Administrators, never to a guessed device. |
| FR-E6 | Images are served from the platform's own cache or signed URLs, not by hotlinking Drive share links. |

#### F. Device Management

| ID | Requirement |
|---|---|
| FR-F1 | All Devices page: table with search, status filter, and row actions (Open Dashboard, Edit, Disable). |
| FR-F2 | Add Device: a short form (device ID, name, location, expected reporting interval, Drive folder or filename prefix, MQTT topic). Validation on device ID uniqueness. |
| FR-F3 | Edit Device: same fields, with Last modified by and Last modified shown. |
| FR-F4 | Delete is a soft delete. Historical readings and images are retained. |

#### G. Alerts

| ID | Requirement |
|---|---|
| FR-G1 | Alert types in Version 1: Device Offline, No Flow, High Flow. |
| FR-G2 | Statuses: New, Acknowledged, Resolved. Each alert links to its device dashboard. |
| FR-G3 | Thresholds are per device with sensible defaults. |

### 1.7 Non-Functional Requirements

| Area | Requirement |
|---|---|
| Performance | Initial dashboard load under 3 seconds. Historical chart query under 1.5 seconds for 30 days using aggregated buckets. |
| Availability | Dashboard remains usable (showing last known data with clear staleness) if EMQX or Drive is temporarily unreachable. |
| Security | TLS everywhere. No MQTT or Drive credentials in the browser. Role-based access enforced on the server. Users can only see devices in their organization. |
| Data integrity | Ingestion is idempotent. Duplicate MQTT messages and duplicate Drive files do not create duplicate records. |
| Auditability | Device edits and alert acknowledgements record who and when. |
| Accessibility | Keyboard navigation, visible focus, contrast that meets WCAG AA, status never conveyed by color alone. |
| Responsiveness | Desktop, tablet, and mobile layouts. Tables collapse to cards on mobile. |

### 1.8 Assumptions and Open Questions

Items below are proposed defaults. They must be confirmed against the real firmware and Drive setup before build begins.

| # | Item | Proposed default |
|---|---|---|
| 1 | Actual MQTT topic structure and payload fields published by EvaraFlow firmware. | See section 3.2. Replace with the real payload once confirmed. |
| 2 | How Drive images are named or foldered so they can be matched to a device. | Filename prefix with device ID (section 3.3). |
| 3 | Whether the device reports a totalizer, or only instantaneous flow. | Totalizer preferred. If absent, the backend integrates flow. |
| 4 | Reporting interval of devices and offline tolerance. | Interval per device. Offline after 3 missed intervals. |
| 5 | Whether readings previously sent to ThingSpeak need to be migrated. | Not migrated in Version 1. EMQX is the only live source. |
| 6 | Who uploads images to Drive (device, phone app, or person). | Any. The platform only reads the folder. |

## Part 6. Roadmap and Delivery Plan

| Phase | Timeline (suggested) | Deliverables |
|---|---|---|
| 0. Confirm | Week 1 | Confirm MQTT payload and Drive naming. Update Decision Log. Approve PRD. |
| 1. Foundation | Weeks 2 to 3 | Database, auth, device CRUD, EMQX subscriber, readings storage. |
| 2. Dashboard core | Weeks 4 to 5 | Selector, Current Reading, chart, table, live updates, switching behavior. |
| 3. Images | Weeks 6 to 7 | Drive sync worker, thumbnails, Latest Image, gallery, lightbox, Unassigned list. |
| 4. Alerts and settings | Week 8 | Three alert types, integration status pages, roles. |
| 5. Hardening | Weeks 9 to 10 | Load test, accessibility, security review, pilot with real devices. |
| 6. Version 1.1 | After pilot | Reports export, more alert types, second product (for example EvaraTDS) on the same shell. |

### Risks

| Risk | Mitigation |
|---|---|
| Firmware payload differs from the assumed contract | Phase 0 confirmation. Strict validation with dead letters so mismatches are visible. |
| Images not named consistently | Prefer per-device subfolders. Unassigned queue for exceptions. |
| Drive API limits or delays | Polling with backoff, sync status visible, manual Sync Now. |
| AI tools invent data or scope | Ground truth file, code review against Definition of Done. |
| Device clocks wrong | Store received_at. Flag readings whose device time differs from server time by more than 5 minutes. |

## Part 7. Recommended Skills and Capabilities to Add

These are capabilities worth adding to the product, and skills worth adding to the AI workflow that builds it.

### 7.1 Product Capabilities (in priority order)

| # | Capability | Value |
|---|---|---|
| 1 | Data freshness and health indicator | Shows exactly how old the data is and whether MQTT and Drive are healthy. Directly supports trust. |
| 2 | Unassigned image inbox | Lets an administrator assign stray images to a device with one click. Avoids wrong guesses. |
| 3 | Image and reading timeline | A combined chronological timeline for a device (still two labeled sources) to see what the meter photo looked like when a reading was taken. Version 1.1. |
| 4 | Photo-versus-reading check | Flag when the meter photo and the reported totalizer disagree. Requires an explicit PRD before build, since it introduces image-derived values. |
| 5 | Anomaly alerts | Unusual night flow, leak pattern, or sudden change from the device's normal profile. |
| 6 | Reports export | PDF, CSV, Excel per device and date range. |
| 7 | Multi-product shell | The same selector, current reading, history, and image pattern for EvaraTDS, EvaraTank, EvaraValve, and others. |
| 8 | Device diagnostics panel | Firmware version, signal strength, last reboot, message rate. Useful for support. |
| 9 | Offline-tolerant history back-fill | Accepts buffered readings that devices send after reconnecting, ordered by device time. |

### 7.2 Skills for the AI Workflow

| Skill | Use |
|---|---|
| Ground truth loader | Always load EVARAFLOW_GROUND_TRUTH.md at the start of a session and restate the goal. |
| Contract-first coding | Before writing ingestion code, update the JSON schema and the Decision Log. |
| Schema validation | Generate and test JSON Schema for MQTT payloads and Zod or Pydantic models from one source. |
| Fixture separation | Keep sample data only in a fixtures folder. Fail the build if fixtures are imported in production code. |
| Time-series query design | Choose aggregation buckets by range and verify query performance. |
| UI state review | For every screen, check loading, empty, error, stale, and switching states against Part 3. |
| Accessibility review | Keyboard, focus, contrast, status not by color alone. |
| Security review | Check that credentials never reach the client and every query is organization-scoped. |
| Documentation sync | When code changes a contract, update Part 2 and the Decision Log in the same change. |

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
