/// Base URL of the EvaraFlow backend (server/ in this repo) — the
/// Express service that handles MQTT/Drive ingestion and the admin-only
/// Drive-backfill trigger used from the Add/Edit Device dialog. Nothing
/// else in this app calls this server: every read goes straight to
/// Firestore (see lib/services/api_service.dart).
///
/// Overridable at build time via `--dart-define=BACKEND_BASE_URL=...` so
/// the same source works for two different deployment shapes without a
/// code change: locally (default below, untouched) the frontend and
/// backend are separate containers on different ports, so this needs a
/// real host:port. On Railway (Dockerfile.railway), frontend and backend
/// run in the same container behind one nginx, so that build passes an
/// empty string here — the resulting relative URL resolves against
/// whatever origin the page was loaded from, same-origin, no CORS, no
/// domain to hardcode.
///
/// Port 8081, not 8080, in the local default: `flutter run -d chrome`
/// defaults its own dev server to 8080, so running both locally at once
/// silently collided (confirmed live, EVARAFLOW_GROUND_TRUTH.md D-017) —
/// whichever process bound the port last won, and the other's /health
/// checks went to the wrong process. server/.env's PORT must match this.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8081',
);
