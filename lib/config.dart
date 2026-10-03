/// Base URL of the EvaraFlow backend (server/ in this repo) — the
/// Express service that handles MQTT/Drive ingestion and the admin-only
/// Drive-backfill trigger used from the Add/Edit Device dialog. Nothing
/// else in this app calls this server: every read goes straight to
/// Firestore (see lib/services/api_service.dart). Hardcoded to the local
/// dev server for now — update this once Railway is actually deployed
/// (see server/README.md).
///
/// Port 8081, not 8080: `flutter run -d chrome` defaults its own dev
/// server to 8080, so running both locally at once silently collided
/// (confirmed live, EVARAFLOW_GROUND_TRUTH.md D-017) — whichever process
/// bound the port last won, and the other's /health checks went to the
/// wrong process. server/.env's PORT must match this value.
const String backendBaseUrl = 'http://localhost:8081';
