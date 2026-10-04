# Serves the already-built Flutter web app via nginx. Deliberately NOT a
# multi-stage build that compiles Flutter inside Docker: that approach
# (building FROM a Flutter-SDK base image like ghcr.io/cirruslabs/flutter)
# was tried first and abandoned — that image is ~1.8GB and its download
# stalled repeatedly on a real test here, making "one command, a few
# minutes" false in practice. Building locally first (fast — a few minutes
# with Flutter already on the machine, no multi-gigabyte pull) and only
# containerizing the tiny serving step is far more reliable.
#
# Run `flutter build web --release` yourself before `docker compose build`
# — the launcher scripts (run.sh/run.ps1/run.bat) do this automatically if
# Flutter is installed, and tell you clearly if it isn't (see their own
# comments for why this still means "no Flutter needed" doesn't fully hold
# for the frontend specifically, unlike the backend).
#
# lib/firebase_options.dart (baked into build/web by the build step, not
# by this Dockerfile) is committed on purpose, not a secret leak: Firebase's
# web config is designed to be public and embedded in client bundles — real
# access control is enforced by Firestore Security Rules. See firestore.rules.

FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
