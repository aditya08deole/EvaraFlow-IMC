/// Base URL of the EvaraFlow backend (server/ in this repo) — the
/// Express service that handles MQTT/Drive ingestion and the admin-only
/// Drive-backfill trigger used from the Add/Edit Device dialog. Nothing
/// else in this app calls this server: every read goes straight to
/// Firestore (see lib/services/api_service.dart). Hardcoded to the local
/// dev server for now — update this once Railway is actually deployed
/// (see server/README.md).
const String backendBaseUrl = 'http://localhost:8080';
