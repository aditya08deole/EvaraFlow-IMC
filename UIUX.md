# EvaraFlow Dashboard: UI/UX Design Document

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

## Part 3. UI/UX Design Document

### 3.1 Design Principles

- One device at a time. The main dashboard never mixes devices.
- Truth over polish. Every value shows when it was recorded. Missing data is stated plainly.
- Two sources, two labels. Readings and images are visually separate sections, each labeled with its source.
- Calm and technical. Light background, navy and blue with teal accent, restrained use of warning colors, no decorative effects.
- Simple first. Detail is one click away, not on the first screen.

### 3.2 Information Architecture

| Sidebar item | Purpose |
|---|---|
| Dashboard | Selected-device view. The home page. |
| All Devices | Table of every device. Add, edit, disable. |
| Alerts | Offline, no flow, high flow events. |
| Reports | Placeholder in Version 1 with Coming soon state. |
| Profile | User details, change password. |
| Settings | General, notifications, integrations (Google Drive, MQTT status), security, users and roles. |

Bottom of the sidebar: user avatar and name, organization name, logout. The sidebar collapses to icons. On mobile it becomes a drawer.

### 3.3 Main Dashboard Layout

Top to bottom, single column on mobile, two columns for the Current Reading and Latest Image on desktop.

1. Device Selector (search field with dropdown).
2. Device header: ID, name, location, status badge, last data received.
3. Current Reading: three cards (Current Flow, Today's Consumption, Last Updated).
4. Latest Image: large image, received time, Source: Google Drive, View All Images button.
5. Historical Readings: chart with range switch (Today, 7 Days, 30 Days, Custom).
6. Past Readings: paginated table (Date and Time, Flow, Consumption, Status).
7. Device Images: strip of the most recent previous images with View All.

### 3.4 Key Screens

#### Device Selector

- Opens on click or keyboard shortcut. Search filters as the user types.
- Rows: status dot, device ID, name, location. Recents pinned on top.
- Keyboard: arrow keys to move, Enter to select, Escape to close.

#### Current Reading

- Large numerals with units. A relative time and exact timestamp under Last Updated.
- A Live indicator while the event stream is connected. A Stale badge replaces it when data is old.

#### Latest Image and Gallery

- Latest Image keeps a fixed aspect ratio to avoid layout shift.
- Gallery: grid of thumbnails, newest first, date and time under each. Infinite scroll or Load more.
- Lightbox: large image, timestamp, file name, previous and next, close, Open in Google Drive for Administrators.

#### Historical Readings

- Line chart for flow with consumption as a second series or toggle.
- Tooltip: timestamp, flow, consumption. Gaps shown as breaks.
- Aggregation label under the chart when data is bucketed.

#### Add and Edit Device

- Single page form in Version 1 (not a long wizard). Sections: Identity, Connectivity (MQTT topic, interval), Image source (Drive match key), Location.
- Inline validation. Save shows a success message and links to the device dashboard.

### 3.5 Loading States

| Area | Loading behavior |
|---|---|
| Whole page first load | App shell renders immediately. Sections show skeletons in their final size to avoid layout shift. |
| Device selector | Skeleton rows while the list loads. Selector stays usable once loaded, even if the rest is loading. |
| Current Reading cards | Skeleton numerals. Never show 0 as a placeholder. |
| Latest Image | Gray placeholder block at fixed aspect ratio. Then fade to the image. Thumbnail loads first, larger size after. |
| Chart | Skeleton chart frame with axes hidden. Range switch stays enabled and cancels the previous request. |
| Past Readings table | Skeleton rows equal to the page size. |
| Slow response (over 8 seconds) | Show Still loading with a Retry link. Do not block other sections. |

### 3.6 Empty States

| Situation | Message and action |
|---|---|
| User has no devices | Add your first EvaraFlow device. Button: Add Device (Administrators). Viewers see: No devices are assigned to your account. Contact your administrator. |
| Search finds nothing in selector | No devices match your search. Clear search. |
| Device exists but has never sent data | Waiting for first reading. Show the expected MQTT topic and reporting interval for Administrators. Status badge: No data yet. |
| No readings in the chosen range | No device data available for this period. Suggest a wider range. |
| Device has no images | No images received yet. Text: Images appear here when uploaded to the connected Google Drive folder. Administrators see the folder name and a link to Settings. |
| Alerts page with no alerts | No active alerts. |
| Unassigned images (Administrators) | No unassigned images. |

### 3.7 Device Switching Behavior

| # | Behavior |
|---|---|
| 1 | Selecting a new device updates the URL (device query parameter) without a full page reload. |
| 2 | All sections reset to their loading state for the new device. Data from the previous device is cleared immediately. It is never left visible while the new device loads. |
| 3 | The live event stream for the previous device is closed and a new one is opened for the selected device. Events for a device that is no longer selected are discarded. |
| 4 | In-flight requests for the previous device are cancelled. A late response for the previous device must not overwrite the new device's view (guard by device ID on every response). |
| 5 | The chart range resets to Today. The Past Readings table returns to page 1. The gallery closes if open. |
| 6 | The chosen device is remembered as the user's last-used device. |
| 7 | Browser Back returns to the previous device. Deep links open the correct device. An invalid or unauthorized device ID shows: This device was not found or you do not have access. Choose another device. |
| 8 | Keyboard focus moves to the device header after switching, and a screen reader announcement states the new device name. |
| 9 | If a device becomes disabled while selected, a banner states it and readings stop updating. |

### 3.8 Error States

| Error | Behavior |
|---|---|
| Readings request fails | Section-level message: Unable to retrieve device data. Retry. Other sections keep working. |
| Image request fails | Message in the image section only. Retry. |
| Live stream disconnects | Live indicator turns to Reconnecting. After the stale threshold: Data feed interrupted. Showing last known reading from (time). |
| Drive sync failed | Settings and Administrator banner: Google Drive sync failed. Last successful sync (time). Sync Now. |
| MQTT disconnected | Settings and Administrator banner with last message time. |
| Permission denied | You do not have permission to view this device. |

### 3.9 Visual Style

| Element | Guideline |
|---|---|
| Color | White or very light gray background. Deep navy text and sidebar. Blue primary. Teal accent for live and positive states. Amber and red only for warnings and errors. |
| Typography | One clean sans-serif family in the app. Numerals in tabular style so live values do not jitter. |
| Shape | Small corner radius, thin borders, subtle shadow. |
| Motion | Minimal. Fade-in for images, gentle highlight when a value updates. No bouncing or looping animations. |
| Status | Dot plus text label (Online, Offline, Stale). Never color alone. |
| Icons | Simple outline icons. |

### 3.10 Responsive Behavior

- Desktop: two-column top area, full table.
- Tablet: single column with compact cards.
- Mobile: selector sticky at top, tables become cards, chart scrolls horizontally if needed, sidebar as a drawer.

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
