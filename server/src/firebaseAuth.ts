/**
 * Admin auth middleware — a genuinely new pattern for this server. Every
 * other route here (/ingest/telemetry, /ingest/drive-image) checks a
 * static X-Webhook-Secret because the caller is a device or a webhook
 * integration, not a person. The admin routes below are instead called by
 * a signed-in human (an administrator) from the Flutter app, so they need
 * real Firebase ID token verification — proving who is calling, not just
 * that they know a shared secret.
 */

import type { Request, Response, NextFunction } from "express";
import "./firebaseAdmin";
import { getAuth } from "firebase-admin/auth";

export async function requireAdmin(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.get("Authorization") ?? "";
  const match = /^Bearer (.+)$/.exec(authHeader);
  if (!match) {
    res.status(401).json({ error: "missing Authorization: Bearer <idToken> header" });
    return;
  }

  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    if (decoded.role !== "administrator") {
      res.status(403).json({ error: "administrator role required" });
      return;
    }
    next();
  } catch (err) {
    console.error("requireAdmin: token verification failed", err);
    res.status(401).json({ error: "invalid or expired ID token" });
  }
}
