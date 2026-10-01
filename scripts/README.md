# Bootstrap scripts

One-off local tools run by hand against the Firebase Admin SDK. Nothing
here is deployed — not to Railway, not to Firebase, not referenced by the
app. Keep it that way; these are too privileged to run anywhere but your
own machine.

## `bootstrapAdmin.js`

Creates (or updates) a Firebase Auth user and sets the `role`/`org_id`
custom claims that `firestore.rules` reads directly to enforce access —
this is Phase 0 step 2 of the mock-data removal plan: the login screen
(`lib/screens/auth/login_screen.dart`) has nothing to sign into until this
has run at least once.

### Setup

```
cd scripts
npm install
```

You'll also need a service-account key — same one described in
`server/README.md` step 1 (Firebase Console → Project Settings → Service
Accounts → Generate new private key). Save the downloaded JSON **outside
this repo** (e.g. your home directory, or anywhere `scripts/.gitignore`
isn't relied on as the only safety net) and pass its path with `--key`.

### Run

```
node bootstrapAdmin.js \
  --key /path/to/service-account.json \
  --email you@yourorg.com \
  --role administrator \
  --org org-evaratech-01 \
  --name "Your Name"
```

- `--role` must be exactly `administrator`, `operator`, or `viewer` — these
  are the literal strings `firestore.rules`' `role()` helper compares
  against.
- `--org` is the `org_id` value Security Rules match against
  `organizations/{org}/...` paths. For now, use a value you intend to
  reuse when you seed real org/device documents in Firestore (Phase 0
  step 3, not yet built) — the two need to match.
- Omit `--password` and the script generates one, prints it once, and
  never stores it. Sign in with it, then use the login screen's "Forgot
  password?" link to replace it with something only you know.
- Safe to re-run with the same `--email`: it finds the existing user and
  updates their claims/profile instead of failing.

### After running

Custom claims are baked into the user's ID token, not read live from
Firestore — a browser tab that was already signed in before you ran this
needs to sign out and back in (or otherwise force a token refresh) before
Security Rules see the new role/org_id.
