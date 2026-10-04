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

# ---- 5. Build and start ----
Write-Host ""
Write-Host "Building and starting the backend..."
docker compose up --build -d
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Failed to start -- see the error above (a common one: port 8081 is already used by something else on this machine)." -ForegroundColor Red
    exit 1
}

# docker compose up -d can report success while the container itself exits
# immediately after (e.g. a port conflict discovered only at container-start
# time) -- confirmed real during testing. Actually check the container is
# up, not just that the CLI command returned.
Start-Sleep -Seconds 2
$state = docker compose ps --format json backend 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $state -or $state.State -ne "running") {
    Write-Host ""
    Write-Host "The container did not stay running. Check what happened:" -ForegroundColor Red
    Write-Host "  docker compose logs"
    exit 1
}

Write-Host ""
Write-Host "Running. Health check: http://localhost:8081/health" -ForegroundColor Green
Write-Host "View logs:   docker compose logs -f"
Write-Host "Stop it:     docker compose down"
