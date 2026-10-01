# EvaraFlow server (Railway)

Two HTTP webhook endpoints — `ingestTelemetry` (MQTT via EMQX Rule Engine)
and `ingestDriveImage` (Google Drive via Apps Script) — that used to be
Firebase Cloud Functions and now run as a plain Express app so they can
deploy on Railway instead. Firestore, Storage, and Security Rules stay on
Firebase (`evaraflow-dash`); this service only holds the compute, reached
through a service-account key since Railway has no Google ADC.

## One-time setup

1. **Get a service-account key.** Firebase Console → Project Settings →
   Service Accounts → *Generate new private key*. This downloads a JSON
   file — keep it off git and out of chat entirely.
2. **Base64-encode it** so it survives Railway's variable editor intact:
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("key.json")) | Set-Clipboard`
   - macOS/Linux: `base64 -w0 key.json | pbcopy` (or `xclip`)
3. **Share the Drive folder.** Open the Drive folder devices upload
   images into → Share → paste the service account's `client_email` →
   Viewer access.
4. **Create the Railway project**: railway.app → New Project → either
   "Deploy from GitHub repo" (point it at this repo, root directory
   `server/`) or `railway init` via the CLI from inside `server/`.
5. **Set environment variables** in the Railway service's Variables tab
   (never in a committed file):
   - `FIREBASE_SERVICE_ACCOUNT_BASE64` — from step 2
   - `FIREBASE_STORAGE_BUCKET` — `evaraflow-dash.firebasestorage.app`
   - `EMQX_WEBHOOK_SECRET` — `openssl rand -hex 32`
   - `DRIVE_WEBHOOK_SECRET` — `openssl rand -hex 32`
   - Railway injects `PORT` itself; don't set it.
6. Railway builds from `server/Dockerfile` and reads `server/railway.json`
   for the healthcheck (`/health`) and restart policy automatically.

## Wiring the two sources at this service

- **EMQX Rule Engine**: point its HTTP action at
  `https://<your-railway-domain>/ingest/telemetry`, header
  `X-Webhook-Secret: <EMQX_WEBHOOK_SECRET value>`.
- **Apps Script**: after the existing Drive upload succeeds, POST
  `{ fileId, fileName }` to `https://<your-railway-domain>/ingest/drive-image`
  with the same header pattern using `DRIVE_WEBHOOK_SECRET`.

## CI/CD

`.github/workflows/deploy-server.yml` (repo root) builds and
type-checks on every push touching `server/**`, then deploys via the
Railway CLI. It needs one repo secret: `RAILWAY_TOKEN` (Railway dashboard
→ Account Settings → Tokens → create a token, then GitHub repo → Settings
→ Secrets and variables → Actions → New repository secret). This repo
isn't a git repository yet — `git init`, push to GitHub, then add that
secret before the workflow can run.

Railway's own "Deploy from GitHub repo" connection (step 4 above) is a
zero-config alternative that auto-deploys on push without any GitHub
Actions file at all; the two aren't mutually exclusive, but running both
means every push deploys twice. Pick one.

## Local dev

```
cp .env.example .env   # fill in real values
npm install
npm run dev             # tsc --watch
node dist/index.js      # separate terminal, after a build exists
```

## Known gaps (carried over from the Cloud Functions version)

- No offline-detection sweep yet — `status.ts` can only prove a device
  *online* (a reading just arrived); detecting silence needs a scheduled
  job, which on Railway would be its own Cron Jobs feature or a separate
  scheduled service, not anything in this repo yet.
- No Drive reconciliation poll — if the Apps Script POST to
  `/ingest/drive-image` is ever lost, nothing currently re-discovers that
  file.
- Alert thresholds (no-flow / high-flow) are an explicit stub in
  `status.ts` pending EVARAFLOW_GROUND_TRUTH.md D-008.
- D-010 (plaintext MQTT), D-011 (QoS 0), D-012 (no device timestamp) are
  still open decisions in EVARAFLOW_GROUND_TRUTH.md, unrelated to the
  Railway-vs-Firebase choice.
