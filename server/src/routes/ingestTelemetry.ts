/**
 * Pipeline A — MQTT telemetry ingestion.
 *
 * Two callers feed the same `processTelemetryMessage` below:
 *   - ingestTelemetryHandler: the EMQX Rule Engine's HTTP action (Option A
 *     in the Firebase backend plan §02), configured in the broker itself,
 *     POSTing to this service's `/ingest/telemetry` route.
 *   - ../mqttBridge: this service connecting to the broker directly as a
 *     subscriber, for when configuring that Rule Engine action isn't
 *     available/done. Same validation, same dead-letter behavior either way.
 *
 * Contract confirmed from real device firmware — EVARAFLOW_GROUND_TRUTH.md
 * D-004/D-005:
 *   topic:   evaratech/v1/{node_id}/telemetry
 *   payload: { node_id, total_liters, flow_rate }  -- no ts, status, or fw.
 *
 * Device identity comes from the TOPIC, not the payload's own node_id
 * field. Confirmed necessary by live traffic: EVT-EF-002's real deployed
 * firmware correctly publishes to its own authorized topic
 * (evaratech/v1/EVT-EF-002/telemetry) but sends payload.node_id: "rpitest"
 * — a leftover test identifier from whatever rig it was last flashed
 * against. The topic is enforced by the broker's per-device MQTT
 * credentials/ACL; the payload's node_id is just a string the firmware
 * can get wrong, as observed here. payload.node_id is no longer checked
 * at all for identity purposes.
 *
 * total_liters also accepts the field name reading_8 as a fallback. Real
 * traffic confirmed the same device's deployed firmware doesn't send
 * total_liters at all — it sends reading_7/reading_8, with reading_8's
 * value matching the totalizer shown on evaratech's own production
 * dashboard (app.evaratech.com) at the same moment. total_liters, if
 * present, still wins — this is a fallback for firmware that doesn't send
 * the documented field name, not a replacement for it.
 *
 * Plausibility checks below (added after a real incident): MQTT auth only
 * proves a publisher is *allowed* to post to a topic, never that it *is*
 * the physical device — a stray test publish with a valid broker password
 * landed on a real device's topic a full day after that device actually
 * went offline, with plausible-looking numbers, and was accepted as
 * genuine telemetry because nothing checked it against physical reality.
 * A real totalizer only ever counts up and a real flow sensor has a
 * physical ceiling, so both are now checked before a reading is trusted.
 * This can't catch everything — a device's very first-ever reading has no
 * prior value to check monotonicity against.
 *
 * A second real incident had previously added an upward-jump-rate check
 * here: a single anomalous reading (total_liters jumping ~438,000 L with
 * flow_rate: null, physically impossible) passed the decrease check — it
 * was an *increase* — and got accepted, becoming a bad baseline. Per
 * EVARAFLOW_GROUND_TRUTH.md D-016, decreases stopped being held back
 * pending confirmation; per D-025, the same philosophy now applies to
 * increases too — the user wants this pipeline to show exactly what EMQX
 * reports, full stop, with no second-guessing of whether a jump "looks"
 * physically plausible in either direction. total_liters is trusted as
 * sent, always, both directions, with no comparison to its previous value
 * at all. What's left, deliberately: rejecting outright negative values,
 * rejecting a message missing both fields entirely, and the flow_rate
 * ceiling below — none of those involve judging a reading against its
 * own history the way the removed check did.
 */

const MAX_PLAUSIBLE_FLOW_LPM = 1000;

import type { Request, Response } from "express";
import { deadLetter, findDeviceByNodeId, insertReading } from "../db";
import { recomputeStatusAndAlerts } from "../status";

interface TelemetryPayload {
  node_id?: unknown;
  total_liters?: unknown;
  reading_8?: unknown;
  flow_rate?: unknown;
}

/**
 * Validates and ingests one MQTT message. Shared by the HTTP webhook path
 * and the direct MQTT subscriber bridge so both dead-letter and insert
 * identically. Throws only on genuine infrastructure failure (e.g.
 * Firestore unavailable) — validation rejections are handled internally via
 * dead-lettering and never throw.
 */
export async function processTelemetryMessage(
  topic: string,
  payload: string
): Promise<void> {
  const topicParts = topic.split("/");
  const nodeId = topicParts[2];
  if (!nodeId) {
    await deadLetter("mqtt", { topic, payload }, "topic has no node_id segment");
    return;
  }

  let parsed: TelemetryPayload;
  try {
    parsed = JSON.parse(payload) as TelemetryPayload;
  } catch {
    await deadLetter("mqtt", { topic, payload }, "invalid JSON");
    return;
  }

  const flow = typeof parsed.flow_rate === "number" ? parsed.flow_rate : null;
  const total =
    typeof parsed.total_liters === "number"
      ? parsed.total_liters
      : typeof parsed.reading_8 === "number"
        ? parsed.reading_8
        : null;
  if ((flow !== null && flow < 0) || (total !== null && total < 0)) {
    await deadLetter("mqtt", parsed, "negative value");
    return;
  }
  if (flow === null && total === null) {
    await deadLetter("mqtt", parsed, "both flow_rate and total_liters missing");
    return;
  }

  const device = await findDeviceByNodeId(nodeId);
  if (!device) {
    await deadLetter("mqtt", parsed, `unknown device ${nodeId}`);
    return;
  }

  if (flow !== null && flow > MAX_PLAUSIBLE_FLOW_LPM) {
    await deadLetter(
      "mqtt",
      parsed,
      `flow_rate ${flow} exceeds plausible ceiling of ${MAX_PLAUSIBLE_FLOW_LPM} L/min`
    );
    return;
  }
  await insertReading(device, { flowLpm: flow, totalL: total, raw: parsed });
  await recomputeStatusAndAlerts(device);
}

export async function ingestTelemetryHandler(
  req: Request,
  res: Response
): Promise<void> {
  // The whole body is wrapped in one try/catch, including the dead-letter
  // writes below: this process serves every concurrent request on Railway
  // (unlike the original Cloud Functions version, where an uncaught
  // rejection only killed that one invocation), so a transient Firestore
  // failure while writing a dead-letter record must not crash the server
  // out from under unrelated in-flight requests and the health check.
  try {
    if (req.get("X-Webhook-Secret") !== process.env.EMQX_WEBHOOK_SECRET) {
      res.status(401).send("unauthorized");
      return;
    }

    // The EMQX Rule Engine SELECT in the plan returns { topic, payload } —
    // `payload` is the raw MQTT message body (JSON-encoded string).
    const { topic, payload } = req.body as { topic?: string; payload?: string };
    if (typeof topic !== "string" || typeof payload !== "string") {
      await deadLetter("mqtt", req.body, "missing topic or payload");
      res.sendStatus(200); // ack the webhook regardless — see note below
      return;
    }

    await processTelemetryMessage(topic, payload);
    res.sendStatus(200);
  } catch (err) {
    // A genuine infrastructure failure (not a validation rejection) —
    // logged and 500'd so the Rule Engine's own retry (if configured)
    // gets a chance, rather than silently swallowing a write failure.
    console.error("ingestTelemetry failed", err);
    res.sendStatus(500);
  }

  // Note on the 200-on-reject pattern above: EMQX's HTTP action generally
  // doesn't distinguish 4xx from 5xx for retry purposes the way a
  // webhook-aware caller would, so validation rejections (which should
  // never be retried — they'd just dead-letter again) return 200, while
  // genuine write failures (which should be retried) return 500. Confirm
  // this matches your actual EMQX Rule Engine retry configuration before
  // relying on it.
}
