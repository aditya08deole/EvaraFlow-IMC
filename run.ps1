# One-command launcher for the EvaraFlow backend, for Windows (PowerShell).
# Usage: .\run.ps1
#
# What this actually does, honestly: checks Docker is installed and tells
# you how to get it if not (it cannot install Docker Desktop for you -- that
# needs an interactive installer and admin rights), checks you've filled in
# server\.env with your own real secrets (it cannot invent your Firebase
# project's credentials or MQTT broker password), then builds and starts the
# backend container. "One command" means one command to START it, not zero
# setup ever -- the secrets step is unavoidable and only needs doing once.

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "EvaraFlow-IMC-Dash backend launcher"
Write-Host "===================================="

# ---- 1. Is Docker installed? ----
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "Docker is not installed." -ForegroundColor Red
    Write-Host "Install Docker Desktop for Windows: https://docs.docker.com/desktop/setup/install/windows-install/"
    Write-Host "Install it, then run this script again."
    exit 1
}
$dockerVersion = docker --version
Write-Host "OK: Docker is installed ($dockerVersion)" -ForegroundColor Green

# ---- 2. Is the Docker daemon actually running? ----
try {
    docker info *> $null
} catch {
    Write-Host "Docker is installed but not running." -ForegroundColor Red
    Write-Host "Start Docker Desktop, then try again."
    exit 1
}
Write-Host "OK: Docker daemon is running" -ForegroundColor Green

# ---- 3. Does docker compose (the v2 plugin) work? ----
try {
    docker compose version *> $null
} catch {
    Write-Host "'docker compose' isn't available." -ForegroundColor Red
    Write-Host "Update Docker Desktop (it bundles this automatically)."
    exit 1
}
Write-Host "OK: docker compose is available" -ForegroundColor Green

# ---- 4. Does server\.env exist with real values? ----
$envPath = "server\.env"
if (-not (Test-Path $envPath)) {
    Write-Host "server\.env doesn't exist yet." -ForegroundColor Yellow
    Copy-Item "server\.env.example" $envPath
    Write-Host "Created it from server\.env.example -- but it's empty. This project is tied to a"
    Write-Host "specific Firebase project and MQTT broker, so no script can fill these in for you:"
    Write-Host "  - FIREBASE_SERVICE_ACCOUNT_BASE64 (required)"
    Write-Host "  - EMQX_WEBHOOK_SECRET / DRIVE_WEBHOOK_SECRET / TAILSCALE_WEBHOOK_SECRET (required)"
    Write-Host "  - MQTT_HOST / MQTT_USERNAME / MQTT_PASSWORD (optional -- only if using the MQTT bridge)"
    Write-Host "See server\README.md for where each of these comes from."
    Write-Host ""
    Write-Host "Open server\.env, fill in real values, then run this script again."
    exit 1
}
$envContent = Get-Content $envPath -Raw
if ($envContent -notmatch "FIREBASE_SERVICE_ACCOUNT_BASE64=\S") {
    Write-Host "server\.env exists but FIREBASE_SERVICE_ACCOUNT_BASE64 is empty." -ForegroundColor Yellow
    Write-Host "Fill in server\.env with your real values (see server\README.md), then run this again."
    exit 1
}
Write-Host "OK: server\.env looks filled in" -ForegroundColor Green

# ---- 5. Build the Flutter web app (locally, not inside Docker) ----
# Tried building this inside Docker first, from a Flutter-SDK base image --
# abandoned after its ~1.8GB download stalled repeatedly on a real test.
# Building locally is fast (a couple minutes) since it reuses whatever
# Flutter/Dart tooling and package cache are already on this machine; only
# the result (build/web, plain static files) gets containerized.
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "Flutter isn't installed -- it's needed to build the dashboard frontend." -ForegroundColor Red
    Write-Host "Install it: https://docs.flutter.dev/get-started/install"
    Write-Host "(The backend alone doesn't need this -- only the dashboard UI does.)"
    exit 1
}
Write-Host "OK: Flutter is installed" -ForegroundColor Green
Write-Host ""
Write-Host "Building the dashboard (flutter build web)... takes a couple minutes."
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter build web failed -- see the error above." -ForegroundColor Red
    exit 1
}

# ---- 6. Build and start the containers ----
Write-Host ""
Write-Host "Starting containers..."
docker compose up --build -d
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Failed to start -- see the error above (a common one: port 8081 or 8090 is already used by something else on this machine)." -ForegroundColor Red
    exit 1
}

# docker compose up -d can report success while a container itself exits
# immediately after (e.g. a port conflict discovered only at container-start
# time) -- confirmed real during testing. Actually check both containers are
# up, not just that the CLI command returned.
Start-Sleep -Seconds 2
$failed = @()
foreach ($svc in @("backend", "frontend")) {
    $state = docker compose ps --format json $svc 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $state -or $state.State -ne "running") {
        $failed += $svc
    }
}
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "These containers did not stay running: $($failed -join ', '). Check what happened:" -ForegroundColor Red
    Write-Host "  docker compose logs"
    exit 1
}

Write-Host ""
Write-Host "Running. Open the dashboard: http://localhost:8090" -ForegroundColor Green
Write-Host "Backend health check:        http://localhost:8081/health"
Write-Host "View logs:   docker compose logs -f"
Write-Host "Stop it:     docker compose down"
