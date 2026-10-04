# Running on Kubernetes (optional)

**Most people should use `run.sh` / `run.ps1` / `run.bat` at the repo root instead** — plain Docker Compose, one command, no cluster needed. Use this folder only if you specifically want this backend running inside a Kubernetes cluster.

## Prerequisites

Some Kubernetes cluster already running and `kubectl` pointed at it — any of these work:
- Docker Desktop's built-in Kubernetes (Settings → Kubernetes → Enable)
- [kind](https://kind.sigs.k8s.io/) (a cluster running inside Docker itself — lightest option if you don't already have one)
- [minikube](https://minikube.sigs.k8s.io/)
- A real cloud cluster (EKS/GKE/AKS) — same manifests work, just skip the "load image" step below and push to a real registry instead

## Steps

1. **Build the image:**
   ```
   docker build -t evaraflow-backend:latest ./server
   ```

2. **Make the image visible to your cluster** (skip this for Docker Desktop's built-in Kubernetes — it already shares the same image store):
   ```
   # kind:
   kind load docker-image evaraflow-backend:latest

   # minikube:
   minikube image load evaraflow-backend:latest
   ```

3. **Create your real secrets** (never commit this file — it's gitignored):
   ```
   cp k8s/secret.example.yaml k8s/secret.yaml
   ```
   Edit `k8s/secret.yaml`, fill in the same real values as `server/.env` (see `server/README.md` for where each one comes from), then:
   ```
   kubectl apply -f k8s/secret.yaml
   ```

4. **Deploy:**
   ```
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   ```

5. **Check it's healthy:**
   ```
   kubectl get pods
   curl http://localhost:30081/health
   ```

## Updating after a code change

```
docker build -t evaraflow-backend:latest ./server
kind load docker-image evaraflow-backend:latest   # or the minikube equivalent; skip for Docker Desktop
kubectl rollout restart deployment/evaraflow-backend
```

## What this doesn't cover

- **Tailscale image pipeline**: the pod needs real network access to your Tailscale network for `TAILSCALE_IMAGE_BASE_URL` to work — Kubernetes pod networking doesn't provide this by default. You'd need to run a Tailscale sidecar container in the same pod (join it with an auth key) and route traffic through it; not set up here since it depends on your specific cluster's networking and isn't needed for the backend's other features to work.
- **TLS/Ingress**: the Service here is a plain NodePort for simplicity. Put a real Ingress controller + cert-manager in front of it before exposing this outside your own machine.
- **Horizontal scaling beyond 1 replica**: the MQTT bridge and Tailscale poller (`startMqttBridge`, `pollTailscaleImages` in `server/src/index.ts`) aren't designed to run as multiple concurrent instances — each would independently subscribe/poll, likely duplicating work. Keep `replicas: 1` unless that's addressed first.
