#!/usr/bin/env bash
# One-command launcher for the EvaraFlow backend, for macOS/Linux.
# Usage: ./run.sh
#
# What this actually does, honestly: checks Docker is installed and tells
# you how to get it if not (it cannot install Docker Desktop for you — that
# needs an interactive installer and admin rights on every platform), checks
# you've filled in server/.env with your own real secrets (it cannot invent
# your Firebase project's credentials or MQTT broker password), then builds
# and starts the backend container. "One command" means one command to
# START it, not zero setup ever — the secrets step is unavoidable and only
# needs doing once.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "EvaraFlow-IMC-Dash backend launcher"
echo "===================================="

# ---- 1. Is Docker installed? ----
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}Docker is not installed.${NC}"
  case "$(uname -s)" in
    Darwin)
      echo "Install Docker Desktop for Mac: https://docs.docker.com/desktop/setup/install/mac-install/"
      ;;
    Linux)
      echo "Install Docker Engine: https://docs.docker.com/engine/install/"
      echo "(On most distros: curl -fsSL https://get.docker.com | sh)"
      ;;
    *)
      echo "See https://docs.docker.com/get-docker/ for your platform."
      ;;
  esac
  echo "Install it, then run this script again."
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker is installed ($(docker --version))"

# ---- 2. Is the Docker daemon actually running? ----
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}Docker is installed but not running.${NC}"
  echo "Start Docker Desktop (or the docker service on Linux: sudo systemctl start docker), then try again."
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker daemon is running"

# ---- 3. Does docker compose (the v2 plugin) work? ----
if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}'docker compose' isn't available.${NC}"
  echo "Docker Desktop includes this automatically — update Docker Desktop, or on Linux install the compose plugin: https://docs.docker.com/compose/install/linux/"
  exit 1
fi
echo -e "${GREEN}✓${NC} docker compose is available"

# ---- 4. Does server/.env exist with real values? ----
if [ ! -f server/.env ]; then
  echo -e "${YELLOW}server/.env doesn't exist yet.${NC}"
  cp server/.env.example server/.env
  echo "Created it from server/.env.example — but it's empty. This project is tied to a"
  echo "specific Firebase project and MQTT broker, so no script can fill these in for you:"
  echo "  - FIREBASE_SERVICE_ACCOUNT_BASE64 (required)"
  echo "  - EMQX_WEBHOOK_SECRET / DRIVE_WEBHOOK_SECRET / TAILSCALE_WEBHOOK_SECRET (required)"
  echo "  - MQTT_HOST / MQTT_USERNAME / MQTT_PASSWORD (optional — only if using the MQTT bridge)"
  echo "See server/README.md for where each of these comes from."
  echo ""
  echo "Open server/.env, fill in real values, then run this script again."
  exit 1
fi
if ! grep -q "^FIREBASE_SERVICE_ACCOUNT_BASE64=.\+" server/.env; then
  echo -e "${YELLOW}server/.env exists but FIREBASE_SERVICE_ACCOUNT_BASE64 is empty.${NC}"
  echo "Fill in server/.env with your real values (see server/README.md), then run this again."
  exit 1
fi
echo -e "${GREEN}✓${NC} server/.env looks filled in"

# ---- 5. Build the Flutter web app (locally, not inside Docker) ----
# Tried building this inside Docker first, from a Flutter-SDK base image --
# abandoned after its ~1.8GB download stalled repeatedly on a real test.
# Building locally is fast (a couple minutes) since it reuses whatever
# Flutter/Dart tooling and package cache are already on this machine; only
# the result (build/web, plain static files) gets containerized.
if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}Flutter isn't installed${NC} -- it's needed to build the dashboard frontend."
  echo "Install it: https://docs.flutter.dev/get-started/install"
  echo "(The backend alone doesn't need this -- only the dashboard UI does.)"
  exit 1
fi
echo -e "${GREEN}✓${NC} Flutter is installed"
echo ""
echo "Building the dashboard (flutter build web)... takes a couple minutes."
flutter build web --release

# ---- 6. Build and start the containers ----
echo ""
echo "Starting containers..."
docker compose up --build -d

# docker compose up -d can report success while a container itself exits
# immediately after (e.g. a port conflict discovered only at container-start
# time) -- confirmed real during testing. Actually check both containers are
# up, not just that the CLI command returned.
sleep 2
failed=""
for svc in backend frontend; do
  state="$(docker compose ps --format json "$svc" 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4)"
  if [ "$state" != "running" ]; then
    failed="$failed $svc"
  fi
done
if [ -n "$failed" ]; then
  echo ""
  echo -e "${RED}These containers did not stay running:${NC}$failed. Check what happened:"
  echo "  docker compose logs"
  exit 1
fi

echo ""
echo -e "${GREEN}Running.${NC} Open the dashboard: http://localhost:8090"
echo "Backend health check:        http://localhost:8081/health"
echo "View logs:   docker compose logs -f"
echo "Stop it:     docker compose down"
