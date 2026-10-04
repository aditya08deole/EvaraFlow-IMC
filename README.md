# EvaraFlow-IMC-Dash

Water-meter monitoring dashboard: MQTT telemetry + two image pipelines (Google Drive, Tailscale) feeding a Flutter dashboard, backed by Firestore. See `EVARAFLOW_GROUND_TRUTH.md` for the full, continuously-updated decision log and ground truth for how this actually works — read that before making architectural changes.

## Quick start — run the backend on any machine

```
./run.sh      # macOS/Linux
.\run.ps1     # Windows (PowerShell)
run.bat       # Windows (double-click, or plain cmd.exe)
```

That one command checks Docker is installed (and tells you how to get it if not — it can't install Docker Desktop for you, that needs an interactive installer), checks `server/.env` is filled in with your real secrets (it can't invent your Firebase project's credentials either — see `server/README.md` for where each one comes from), then builds and starts the backend in a container. First run builds the image (~1-2 min); every run after that is fast.

```
docker compose logs -f     # watch it
docker compose down        # stop it
```

Prefer Kubernetes instead of plain Docker? See `k8s/README.md` — same backend, deployed into a cluster.

**What this does and doesn't solve:** Docker removes "do I have the right Node version / dependencies installed" as a problem. It does *not* remove the need for this project's own real secrets (Firebase service account, MQTT broker credentials) — those are specific to this deployment and nothing can generate them for you. Fill in `server/.env` once; after that, it's genuinely one command per machine.

## What's in this repo

| Path | What it is |
|---|---|
| `lib/` | The Flutter dashboard (web/mobile client) — reads straight from Firestore, never calls the backend except for the Add/Edit Device admin actions. |
| `server/` | The Node/Express backend — MQTT bridge, Google Drive + Tailscale image ingestion, dead-letter queue. See `server/README.md`. |
| `tailscale-image-server/` | `server_v3.py`, the Flask image receiver devices upload to, run separately on whichever machine has the camera/Pi attached. |
| `k8s/` | Optional Kubernetes manifests for the backend, as an alternative to Docker Compose. |
| `EVARAFLOW_GROUND_TRUTH.md` | The actual source of truth for this project's confirmed decisions, contracts, and incident history. Read this first. |

## Running the Flutter dashboard itself

```
flutter pub get
flutter run -d chrome    # or your platform of choice
```

The dashboard reads Firestore directly — it needs your own Firebase project configured (see `lib/firebase_options.dart` / FlutterFire setup), not the Docker backend above. The backend is only needed for ingestion (MQTT/Drive/Tailscale → Firestore) and the admin-only Drive-backfill action.
