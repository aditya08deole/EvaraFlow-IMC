// Loads server/.env into process.env for local dev; on Railway this is a
// harmless no-op since there's no .env file there — real values come from
// the Variables tab instead.
import "dotenv/config";
import "./firebaseAdmin";
import express from "express";
import type { Request, Response, NextFunction } from "express";
import { ingestTelemetryHandler } from "./routes/ingestTelemetry";
import { ingestDriveImageHandler } from "./routes/ingestDriveImage";
import { ingestTailscaleImageHandler } from "./routes/ingestTailscaleImage";
import { backfillDriveImagesHandler } from "./routes/backfillDriveImages";
import { requireAdmin } from "./firebaseAuth";
import { startMqttBridge } from "./mqttBridge";
import { sweepOfflineDevices } from "./status";
import { pollTailscaleImages } from "./tailscalePoll";

const app = express();
app.use(express.json({ limit: "1mb" }));

// Railway's healthcheck (configured in railway.json) hits this before
// routing traffic to a new deploy.
app.get("/health", (_req, res) => {
  res.status(200).send("ok");
});

app.post("/ingest/telemetry", ingestTelemetryHandler);
app.post("/ingest/drive-image", ingestDriveImageHandler);
app.post("/ingest/tailscale-image", ingestTailscaleImageHandler);

// Everything above is called by devices/webhooks, never a browser, so it
// never needed CORS. The admin routes below are called directly from the
// Flutter app running in a browser (localhost:5050 in dev), which the
// browser blocks without explicit CORS headers. Scoped to /admin/* only —
// allow-all is fine for a localhost demo, but tighten this to a specific
// origin before this server runs anywhere else.
function adminCors(req: Request, res: Response, next: NextFunction): void {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.header("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") {
    res.sendStatus(204);
    return;
  }
  next();
}

app.post(
  "/admin/backfill-drive-images",
  adminCors,
  requireAdmin,
  backfillDriveImagesHandler
);
app.options("/admin/backfill-drive-images", adminCors);

const port = Number(process.env.PORT) || 8080;
app.listen(port, () => {
  console.log(`evaraflow-server listening on ${port}`);
});

startMqttBridge();

// No Cloud Scheduler on Railway — this always-on process's own
// setInterval stands in for one. 60s keeps the stored `status` field
// (not just its client-side display) catching up to real silence quickly
// relative to any realistic expectedIntervalSeconds, without hammering
// Firestore.
setInterval(() => {
  sweepOfflineDevices().catch((err) => {
    console.error("sweepOfflineDevices failed", err);
  });
}, 60_000);

// Optional, same pattern as startMqttBridge: only runs when
// TAILSCALE_IMAGE_BASE_URL is set (pollTailscaleImages no-ops otherwise).
// 5 minutes, not 60s like the status sweep — the Tailscale server's own
// /list response lists its entire history (tens of thousands of
// filenames at demo time) on every call, so this polls far less
// aggressively than the lightweight Firestore sweep above.
setInterval(() => {
  pollTailscaleImages().catch((err) => {
    console.error("pollTailscaleImages failed", err);
  });
}, 5 * 60_000);
// Also run once at startup rather than waiting a full 5 minutes for the
// first check.
pollTailscaleImages().catch((err) => {
  console.error("pollTailscaleImages failed", err);
});
