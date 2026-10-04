# EvaraFlow-IMC-Dash

Water-meter monitoring dashboard: MQTT telemetry + two image pipelines (Google Drive, Tailscale) feeding a Flutter dashboard, backed by Firestore. See `EVARAFLOW_GROUND_TRUTH.md` for the full, continuously-updated decision log and ground truth for how this actually works — read that before making architectural changes.

This README has two completely separate ways to run the project — pick one:

- **[Run it with Docker](#run-it-with-docker)** — the backend needs no Node install at all; the dashboard needs Flutter installed once (the launcher builds it for you), but nothing else — no manual server setup, consistent on any machine.
- **[Run it locally, no Docker](#run-it-locally-no-docker)** — for active development (hot reload, debugging).

---

## Run it with Docker

### The simple version

1. Install Docker Desktop if you don't have it: <https://www.docker.com/products/docker-desktop/>. Open it and wait until it says it's running.
2. Fill in your secrets once: copy `server/.env.example` to `server/.env` and fill in the real values (see [Where do the secrets come from?](#where-do-the-secrets-come-from) below).
3. Run the one command for your OS, from the repo root:

   | Your OS | Command |
   |---|---|
   | Windows (PowerShell) | `.\run.ps1` |
   | Windows (double-click) | double-click `run.bat` |
   | macOS / Linux | `./run.sh` |

4. Wait for it to say **"Running. Open the dashboard: http://localhost:8090"** — the script builds the dashboard with your local Flutter install first (a couple minutes), then starts the containers (fast, under a minute, especially after the first run).
5. Open **http://localhost:8090** in your browser. That's the actual dashboard.

### The detailed version — what's actually happening at each step

**Step 1 — Docker.** The backend gets packaged into a container with the exact right Node version already inside it — you never install Node yourself. The launcher script checks for Docker and tells you exactly what to click if it's missing; it cannot install Docker Desktop for you (that needs you to click through an installer and grant admin rights, which no script should ever try to do silently).

**Step 1b — Flutter, for the dashboard specifically.** The dashboard's build step (`flutter build web`) runs on your own machine, not inside a container — an earlier attempt to build it inside Docker (from a ~1.8GB Flutter-SDK image) was abandoned after that download stalled repeatedly on a real test here, making it unreliable. So Flutter needs to be installed once: <https://docs.flutter.dev/get-started/install>. The launcher checks for it and tells you if it's missing — just that one install, then the script handles the actual build every time.

**Step 2 — secrets.** This project talks to a specific Firebase project and a specific MQTT broker — things only you (or your team) have the login details for. No script, container, or AI can invent a real password for your own Firebase project. `server/.env.example` lists every value needed, with a comment above each one saying where it comes from. Copy it to `server/.env` and fill in the real values once — you only ever do this one time per machine.

**Step 3 — the one command.** Each launcher script (`run.sh` for Mac/Linux, `run.ps1`/`run.bat` for Windows) does the same things, in order:
   1. Checks `docker` is installed.
   2. Checks the Docker *daemon* is actually running (Docker Desktop can be installed but not open).
   3. Checks `docker compose` (the orchestration tool that starts multiple containers together) works.
   4. Checks `server/.env` exists and actually has real values in it — not just an empty copy of the example file.
   5. Checks `flutter` is installed, then runs `flutter build web --release` — this produces plain static HTML/JS/CSS in `build/web/`.
   6. Runs `docker compose up --build -d`, which builds two containers (reading `docker-compose.yml` at the repo root) and starts both:
      - **`frontend`** — serves the just-built `build/web/` with nginx on port **8090**.
      - **`backend`** — the Node ingestion service (MQTT bridge, image pipelines) on port **8081**.

**Step 4 — what you'll see.** The dashboard itself is what's on port 8090 — that's the one you open in a browser. Port 8081 is just the backend's API; opening that directly in a browser only shows the text `ok` (its health check), which is expected and not a sign anything's wrong.

**Step 5 — everyday commands**, once it's set up:

```
docker compose logs -f       # watch both containers' output live
docker compose ps             # check what's running and whether it's healthy
docker compose down           # stop everything
docker compose up --build -d  # rebuild (after you change code) and start again
```

**Seeing it in Docker Desktop's own window:** open Docker Desktop, click **Containers** in the left sidebar (not a specific project's "App" view, which only shows that one project). You should see a group called `evaraflow-imc-dash` with two containers inside it, both marked healthy/running.

### Where do the secrets come from?

See `server/.env.example` — every line has a comment above it. Short version: `FIREBASE_SERVICE_ACCOUNT_BASE64` comes from your Firebase project's Service Account settings; the `*_WEBHOOK_SECRET` values are just random strings you make up yourself (`openssl rand -hex 32`); the `MQTT_*` values are credentials for the actual broker this deployment talks to. Full detail in `server/README.md`.

### Prefer Kubernetes instead of plain Docker?

See `k8s/README.md` — same backend, deployed into a cluster instead of via Compose. Optional; most people should just use the scripts above.

---

## Run it locally, no Docker

Use this if you're actively developing — editing code and wanting to see changes immediately (hot reload), rather than rebuilding a container each time.

### The simple version

**Backend** (in one terminal):
```
cd server
cp .env.example .env     # fill in real values, same as the Docker path
npm install
npm run build
npm start
```

**Frontend** (in a separate terminal):
```
flutter pub get
flutter run -d chrome
```

### The detailed version

**Backend, step by step:**
1. You need [Node.js 20](https://nodejs.org/) installed (check with `node --version`).
2. `cd server` — everything backend-related lives in this folder.
3. `cp .env.example .env`, then open `.env` and fill in real values (see [Where do the secrets come from?](#where-do-the-secrets-come-from) above) — same secrets as the Docker path, just a plain file instead of something baked into a container.
4. `npm install` — downloads the backend's dependencies (Express, the MQTT client, Firebase Admin SDK, etc.) into `server/node_modules/`.
5. `npm run build` — compiles the TypeScript source in `server/src/` into plain JavaScript in `server/dist/`, since Node can't run TypeScript directly.
6. `npm start` runs `node dist/index.js` — the actual server. You should see `evaraflow-server listening on 8081` and (if `MQTT_HOST` is set in `.env`) `mqttBridge connected`.
7. Health check: open `http://localhost:8081/health` — should show `ok`.

Want it to survive if it crashes, without a Docker container? `npm run build` then `node run-persistent.js` instead of `npm start` — a tiny supervisor that restarts it automatically. See the comment at the top of `server/run-persistent.js` for exactly what this does and doesn't cover.

**Frontend, step by step:**
1. You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (check with `flutter --version`; this project needs Dart SDK `^3.10.4` or newer, which comes bundled with a recent-enough Flutter release).
2. From the repo root (not `server/`): `flutter pub get` — downloads the Flutter packages this app depends on.
3. `flutter run -d chrome` builds and opens the app in Chrome, with hot reload: save a file and press `r` in that terminal to see the change instantly, or `R` for a full restart.
4. The app reads Firestore **directly** — it needs your own Firebase project wired up via `lib/firebase_options.dart` (already committed in this repo; regenerate it with `flutterfire configure` if you're pointing this at a different Firebase project). It does **not** need the backend running at all for normal viewing — only the Add/Edit Device dialog's Drive-folder-backfill button calls the backend (`lib/config.dart`'s `backendBaseUrl`, which defaults to `http://localhost:8081` — update it if your backend runs somewhere else).

---

## What's in this repo

| Path | What it is |
|---|---|
| `lib/` | The Flutter dashboard (web/mobile client) — reads straight from Firestore, never calls the backend except for the Add/Edit Device admin actions. |
| `server/` | The Node/Express backend — MQTT bridge, Google Drive + Tailscale image ingestion, dead-letter queue. See `server/README.md`. |
| `tailscale-image-server/` | `server_v3.py`, the Flask image receiver devices upload to, run separately on whichever machine has the camera/Pi attached. |
| `k8s/` | Optional Kubernetes manifests for the backend, as an alternative to Docker Compose. |
| `docker-compose.yml`, `Dockerfile`, `server/Dockerfile` | The Docker setup described above — root `Dockerfile` builds the frontend, `server/Dockerfile` builds the backend. |
| `run.sh` / `run.ps1` / `run.bat` | The one-command launchers described above. |
| `EVARAFLOW_GROUND_TRUTH.md` | The actual source of truth for this project's confirmed decisions, contracts, and incident history. Read this first. |

## Troubleshooting

- **"Docker is installed but not running"** — open the Docker Desktop app itself and wait for it to finish starting before running the script again.
- **A port is already in use (8081 or 8090)** — something else on your machine is using that port. Find and stop it, or if you're intentionally also running the backend locally without Docker at the same time, stop one of the two — they can't both use the same port.
- **Changes to the backend code aren't showing up after `docker compose up`** — Docker caches build layers. Run `docker compose up --build -d` (note `--build`) to force a rebuild, or `docker compose build --no-cache` for a completely clean one.
- **Changes to the Flutter dashboard code aren't showing up** — the frontend container just serves whatever's already in `build/web/` as plain static files; it doesn't know when your Dart source changed. Run `flutter build web --release` again (or just re-run `./run.sh` / `.\run.ps1`), then `docker compose up --build -d`.
- **The dashboard loads but shows no data** — check you're signed in with an account that has an `org_id` custom claim set (see `server/src/scripts/setUserClaims.ts`), and that at least one device is registered (`npm run seed:device` in `server/`, or the Add Device dialog in the app itself).
