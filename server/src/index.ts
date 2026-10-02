// Loads server/.env into process.env for local dev; on Railway this is a
// harmless no-op since there's no .env file there — real values come from
// the Variables tab instead.
import "dotenv/config";
import "./firebaseAdmin";
import express from "express";
import { ingestTelemetryHandler } from "./routes/ingestTelemetry";
import { ingestDriveImageHandler } from "./routes/ingestDriveImage";
import { startMqttBridge } from "./mqttBridge";

const app = express();
app.use(express.json({ limit: "1mb" }));

// Railway's healthcheck (configured in railway.json) hits this before
// routing traffic to a new deploy.
app.get("/health", (_req, res) => {
  res.status(200).send("ok");
});

app.post("/ingest/telemetry", ingestTelemetryHandler);
app.post("/ingest/drive-image", ingestDriveImageHandler);

const port = Number(process.env.PORT) || 8080;
app.listen(port, () => {
  console.log(`evaraflow-server listening on ${port}`);
});

startMqttBridge();
