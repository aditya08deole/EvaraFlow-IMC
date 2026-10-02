/**
 * One-off admin utility: sets the `org_id`/`role` custom claims that
 * firestore.rules (EVARAFLOW_GROUND_TRUTH.md D-013) requires on a Firebase
 * Auth user's ID token before any of their Firestore reads are allowed.
 * There is no self-service signup (lib/screens/auth/login_screen.dart is
 * sign-in only) — an administrator runs this once per account after
 * creating it in the Firebase Console (Authentication -> Add user).
 *
 * Usage (after `npm run build`, with FIREBASE_SERVICE_ACCOUNT_BASE64 set):
 *   node dist/scripts/setUserClaims.js --email=you@org.com --org-id=org-001 --role=administrator
 *
 * The user must sign out and back in (or call getIdToken(true)) for the
 * new claims to show up in their ID token — Firebase caches tokens for up
 * to an hour otherwise.
 */

import "dotenv/config";

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const arg of argv) {
    const match = /^--([^=]+)=(.*)$/.exec(arg);
    if (match) out[match[1]] = match[2];
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const email = args["email"];
  const orgId = args["org-id"];
  const role = args["role"];

  if (!email || !orgId || !role) {
    console.error(
      "Usage: node dist/scripts/setUserClaims.js --email=you@org.com --org-id=org-001 --role=administrator"
    );
    process.exitCode = 1;
    return;
  }
  if (role !== "administrator" && role !== "operator") {
    console.error(`Invalid role "${role}" — must be "administrator" or "operator".`);
    process.exitCode = 1;
    return;
  }

  // Imported only after arg validation above, so running with no args
  // prints usage even when FIREBASE_SERVICE_ACCOUNT_BASE64 isn't set yet.
  await import("../firebaseAdmin");
  const { getAuth } = await import("firebase-admin/auth");
  const auth = getAuth();

  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, { org_id: orgId, role });

  console.log(
    `Set custom claims for ${email} (uid ${user.uid}): org_id=${orgId}, role=${role}.\n` +
      `They must sign out and sign back in for this to take effect.`
  );
}

main().catch((err) => {
  console.error("setUserClaims failed", err);
  process.exitCode = 1;
});
