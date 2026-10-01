#!/usr/bin/env node
/**
 * One-off local tool: creates (or updates) a Firebase Auth user and sets
 * the role/org_id custom claims that firestore.rules reads directly
 * (role() / orgId() helpers — see firestore.rules). Run by hand from your
 * own machine against a service-account key; never deployed, never wired
 * into the app or the Railway server.
 *
 * Usage:
 *   node bootstrapAdmin.js --key ./service-account.json \
 *     --email you@org.com --role administrator --org org-evaratech-01 \
 *     [--name "Your Name"] [--password "..."]
 *
 * If --password is omitted, a random one is generated and printed once —
 * sign in with it, then use the login screen's "Forgot password?" link to
 * replace it immediately. Re-running with an existing --email is safe
 * (idempotent upsert): it updates claims/profile on the existing user
 * instead of failing.
 *
 * IMPORTANT: custom claims only take effect on the client's next sign-in
 * (or a forced ID-token refresh) — a tab that was already signed in before
 * this script ran will keep seeing stale claims until it re-authenticates.
 */

const admin = require("firebase-admin");
const crypto = require("crypto");

const VALID_ROLES = ["administrator", "operator", "viewer"];

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        out[key] = true;
      } else {
        out[key] = next;
        i++;
      }
    }
  }
  return out;
}

function generatePassword() {
  const chars =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_!@#";
  const bytes = crypto.randomBytes(20);
  return Array.from(bytes, (b) => chars[b % chars.length]).join("");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const keyPath = args.key;
  const email = args.email;
  const role = args.role;
  const orgId = args.org;
  const displayName = args.name || email;
  let password = args.password;

  const missing = [];
  if (!keyPath) missing.push("--key <path to service-account.json>");
  if (!email) missing.push("--email <you@org.com>");
  if (!role) missing.push("--role <administrator|operator|viewer>");
  if (!orgId) missing.push("--org <org_id>");
  if (missing.length) {
    console.error("Missing required arguments:\n  " + missing.join("\n  "));
    console.error(
      "\nSee the header comment in this file, or scripts/README.md, for full usage."
    );
    process.exit(1);
  }
  if (!VALID_ROLES.includes(role)) {
    console.error(
      `--role must be one of: ${VALID_ROLES.join(", ")} (matches firestore.rules' role() checks exactly)`
    );
    process.exit(1);
  }

  const path = require("path");
  const resolvedKeyPath = path.resolve(process.cwd(), keyPath);
  const serviceAccount = require(resolvedKeyPath);

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

  let generatedPassword = false;
  if (!password) {
    password = generatePassword();
    generatedPassword = true;
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
    const updates = { displayName };
    if (args.password) updates.password = password; // only overwrite if explicitly given
    user = await admin.auth().updateUser(user.uid, updates);
    console.log(`Existing user found — updated: ${email} (${user.uid})`);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    user = await admin.auth().createUser({ email, password, displayName });
    console.log(`Created new user: ${email} (${user.uid})`);
  }

  await admin.auth().setCustomUserClaims(user.uid, { role, org_id: orgId });

  await admin
    .firestore()
    .collection("users")
    .doc(user.uid)
    .set(
      {
        email,
        displayName,
        role,
        orgId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  console.log("\nDone.");
  console.log(`  uid:      ${user.uid}`);
  console.log(`  email:    ${email}`);
  console.log(`  role:     ${role}`);
  console.log(`  org_id:   ${orgId}`);
  if (generatedPassword) {
    console.log(`  password: ${password}  (generated — shown once, not stored anywhere)`);
    console.log(
      "\nSign in with this password, then use \"Forgot password?\" on the login screen to replace it."
    );
  }
  console.log(
    "\nIf this account was already signed in somewhere, it must sign out and back in (or refresh its ID token) before the new claims take effect — Firestore Security Rules read claims from the token, not live from this script."
  );

  process.exit(0);
}

main().catch((err) => {
  console.error("\nBootstrap failed:", err.message || err);
  process.exit(1);
});
