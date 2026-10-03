# Tailscale image server

Run this on the laptop/Pi that receives photos from your devices. Not part
of the Node backend in `server/` — a separate Python/Flask process, kept in
its own folder here.

## Setup

1. Set the shared secret as an environment variable — **do not** paste it
   directly into `server_v3.py`, since this file is committed to git and a
   secret pasted into it would end up in git history permanently. It must
   exactly match `TAILSCALE_WEBHOOK_SECRET` in `server/.env` (already
   generated there — open that file to see the value):
   - Windows (PowerShell): `$env:EVARAFLOW_WEBHOOK_SECRET = "paste-the-server/.env-value-here"`
   - macOS/Linux: `export EVARAFLOW_WEBHOOK_SECRET="paste-the-server/.env-value-here"`
2. Then:
   ```
   pip install flask requests
   python3 server_v3.py
   ```
   It'll print a warning on startup if the secret isn't set.

## The only thing you might need to change in the file itself

Near the top of `server_v3.py`:

```python
EVARAFLOW_WEBHOOK_URL = "http://localhost:8081/ingest/tailscale-image"
```

This already matches the default setup (EvaraFlow backend running locally
on this same machine, on port 8081). Change it only if:
- The EvaraFlow backend runs on a **different** machine on your Tailscale
  network — use that machine's Tailscale address instead of `localhost`.
- The EvaraFlow backend is deployed to Railway — use
  `https://<your-railway-domain>/ingest/tailscale-image`.

## What you still need to do yourself (outside this file)

1. Get this machine's Tailscale address: run `tailscale ip -4` here.
2. Put that address into `TAILSCALE_IMAGE_BASE_URL` in `server/.env`
   (e.g. `http://100.x.y.z:5000`).
3. Make sure the EvaraFlow backend (`server/`) is running — it's what
   actually fetches each photo and makes it visible on the dashboard.
