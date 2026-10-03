#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===============================================================
  Smart Water Meter — Multi-Node Image Receiver Server
  -------------------------------------------------------
  Accepts images from any node (EVT-EF-001, EVT-EF-002, etc.)
  via two upload formats:

    1. Multipart form-data  (pi_capture.py / pi_edge_pipeline)
         POST /upload
         Header: X-Node-ID: EVT-EF-001
         Body:   multipart/form-data, field name = "file"

    2. Raw body — Base64 OR raw JPEG  (ESP32-CAM nodes)
         POST /upload
         Header: X-Node-ID: node-1
         Body:   base64-encoded bytes  OR  raw JPEG bytes

  Other endpoints:
    GET  /list                   JSON list of all images (all nodes)
    GET  /list?node=EVT-EF-001   filter by node
    GET  /images/<node>/<filename>   serve a saved image
    GET  /health                 health check + image count
    DELETE /images/<node>/<filename> delete a specific image

  Folder layout (NEW):
    images_s/
      EVT-EF-001/
        EVT-EF-001_20260415_123045.jpg
      EVT-EF-002/
        EVT-EF-002_20260415_123112.jpg

  Usage:
    pip install flask requests
    python3 server_v3.py

  With Tailscale (replaces ngrok):
    Pi uses: http://<laptop-tailscale-ip>:5000
    No extra tunnel command needed.

  ---------------------------------------------------------------
  EvaraFlow integration (added):
  Right after an image is saved, this server notifies the EvaraFlow
  backend (server/ in the EvaraFlow-IMC-Dash repo) so the photo shows
  up in the dashboard gallery automatically — see notify_evaraflow()
  and its one call site inside upload() below. If that notification
  fails for any reason, the upload itself still succeeds; only the
  dashboard update is affected, and only until the next successful
  upload for that device.
===============================================================
"""

import os
import base64
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
import requests  # pip install requests

app = Flask(__name__)

# ── Config ─────────────────────────────────────────────────────
SAVE_FOLDER = "images_s"
os.makedirs(SAVE_FOLDER, exist_ok=True)

# ── EvaraFlow backend webhook config ────────────────────────────
# EVARAFLOW_WEBHOOK_URL: where the EvaraFlow backend (server/ in the
# EvaraFlow-IMC-Dash repo) is reachable from THIS machine.
#   - If that backend is running locally on this same machine (the usual
#     setup while developing): http://localhost:8081/ingest/tailscale-image
#   - If it's running on a different machine on the same Tailscale network:
#     http://<that machine's tailscale address>:8081/ingest/tailscale-image
#   - If it's deployed to Railway: https://<your-railway-domain>/ingest/tailscale-image
EVARAFLOW_WEBHOOK_URL = "http://localhost:8081/ingest/tailscale-image"

# Must exactly match TAILSCALE_WEBHOOK_SECRET in the backend's server/.env
# (and on Railway's Variables tab, if deployed there). Read from an
# environment variable, not hardcoded here — this file is committed to
# git, and a secret pasted directly into it would end up in git history
# permanently. Set it before running (see README.md in this folder):
#   Windows (PowerShell):  $env:EVARAFLOW_WEBHOOK_SECRET = "paste-it-here"
#   macOS/Linux:            export EVARAFLOW_WEBHOOK_SECRET="paste-it-here"
EVARAFLOW_WEBHOOK_SECRET = os.environ.get("EVARAFLOW_WEBHOOK_SECRET", "")
if not EVARAFLOW_WEBHOOK_SECRET:
    print(" [!] WARNING: EVARAFLOW_WEBHOOK_SECRET is not set — the backend "
          "will reject every notification with 401 until it's set. See README.md.")


def notify_evaraflow(node_id, filename):
    """
    Tells the EvaraFlow backend a new image landed, so it shows up in the
    dashboard gallery — mirrors how the existing Google Drive pipeline's
    Apps Script notifies that same backend right after a Drive upload.
    Never raises: a webhook failure must not break the actual image
    upload/save, which has already succeeded by the time this runs.
    """
    try:
        resp = requests.post(
            EVARAFLOW_WEBHOOK_URL,
            json={"node_id": node_id, "filename": filename},
            headers={"X-Webhook-Secret": EVARAFLOW_WEBHOOK_SECRET},
            timeout=5,
        )
        if resp.status_code != 200:
            print(" [!] EvaraFlow webhook returned {}: {}".format(resp.status_code, resp.text))
        else:
            print(" [>] Notified EvaraFlow: {}/{}".format(node_id, filename))
    except Exception as e:
        print(" [!] EvaraFlow webhook failed: {}".format(e))


# ── Helpers ────────────────────────────────────────────────────
def sanitise_node_id(raw):
    """
    Allow letters, numbers, hyphens, underscores.
    Handles: EVT-EF-001, node-1, retrofit3, etc.
    """
    cleaned = "".join(c for c in str(raw).strip() if c.isalnum() or c in "-_")
    return cleaned if cleaned else "node-unknown"


def node_folder(node_id):
    """Return (and create) the subfolder path for a given node."""
    path = os.path.join(SAVE_FOLDER, node_id)
    os.makedirs(path, exist_ok=True)
    return path


def save_image(img_bytes, node_id):
    """Save image bytes to SAVE_FOLDER/<node_id>/, return filename."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename  = "{}_{}.jpg".format(node_id, timestamp)
    filepath  = os.path.join(node_folder(node_id), filename)
    with open(filepath, "wb") as f:
        f.write(img_bytes)
    return filename


# ── POST /upload ───────────────────────────────────────────────
@app.route("/upload", methods=["POST"])
def upload():
    """
    Accept images from any node in two formats.

    Format 1 — Multipart (Pi nodes via requests.post files=):
        headers = {"X-Node-ID": "EVT-EF-001"}
        files   = {"file": ("name.jpg", data, "image/jpeg")}

    Format 2 — Raw body (ESP32-CAM / other embedded nodes):
        headers = {"X-Node-ID": "node-1"}
        data    = base64_encoded_bytes  OR  raw_jpeg_bytes
    """
    try:
        node_id = sanitise_node_id(
            request.headers.get("X-Node-ID", "node-unknown")
        )

        img_bytes = None

        # ── Format 1: multipart/form-data ─────────────────────
        if "file" in request.files:
            img_bytes = request.files["file"].read()
            if not img_bytes:
                return jsonify({"status": "error",
                                "message": "Multipart file is empty"}), 400

        # ── Format 2: raw body ────────────────────────────────
        elif request.data:
            raw = request.data

            # Detect format:
            #   Raw JPEG always starts with magic bytes 0xFF 0xD8
            #   Base64 is printable ASCII — no JPEG magic at start
            if raw[:2] == b"\xff\xd8":
                # Already raw JPEG
                img_bytes = raw
            else:
                # Assume base64 — strip whitespace before decoding
                try:
                    img_bytes = base64.b64decode(raw.strip())
                except Exception as e:
                    return jsonify({"status": "error",
                                    "message": "Base64 decode failed: {}".format(e)}), 400

        else:
            return jsonify({"status": "error",
                            "message": "No file or body in request"}), 400

        # ── Validate JPEG magic bytes ──────────────────────────
        if not img_bytes or img_bytes[:2] != b"\xff\xd8":
            return jsonify({"status": "error",
                            "message": "Data is not a valid JPEG"}), 400

        filename = save_image(img_bytes, node_id)
        print(" [+] Saved: {}/{}  ({:,} bytes)".format(node_id, filename, len(img_bytes)))
        notify_evaraflow(node_id, filename)
        return jsonify({"status": "ok", "node": node_id, "filename": filename}), 200

    except Exception as e:
        print(" [!] Upload error: {}".format(e))
        return jsonify({"status": "error", "message": str(e)}), 500


# ── GET /list ──────────────────────────────────────────────────
@app.route("/list", methods=["GET"])
def list_images():
    """
    Returns sorted JSON list of saved images, grouped by node.
    Optional filter: ?node=EVT-EF-001  ->  only that node's images
    """
    try:
        node_filter = sanitise_node_id(request.args.get("node", ""))

        result = {}
        if os.path.isdir(SAVE_FOLDER):
            for node_id in sorted(os.listdir(SAVE_FOLDER)):
                node_path = os.path.join(SAVE_FOLDER, node_id)
                if not os.path.isdir(node_path):
                    continue
                if node_filter and node_filter != "node-unknown" and node_id != node_filter:
                    continue
                files = sorted(f for f in os.listdir(node_path) if f.endswith(".jpg"))
                result[node_id] = files

        total = sum(len(v) for v in result.values())
        return jsonify({"nodes": result, "count": total}), 200
    except Exception as e:
        print(" [!] List error: {}".format(e))
        return jsonify({"status": "error", "message": str(e)}), 500


# ── GET /images/<node>/<filename> ───────────────────────────────
@app.route("/images/<node_id>/<filename>", methods=["GET"])
def serve_image(node_id, filename):
    """Serve a saved image file from its node's subfolder."""
    try:
        node_id = sanitise_node_id(node_id)
        return send_from_directory(os.path.join(SAVE_FOLDER, node_id), filename)
    except Exception:
        return jsonify({"status": "error", "message": "File not found"}), 404


# ── GET /health ────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    """Health check — confirms server is running and shows image count per node."""
    try:
        counts = {}
        if os.path.isdir(SAVE_FOLDER):
            for node_id in sorted(os.listdir(SAVE_FOLDER)):
                node_path = os.path.join(SAVE_FOLDER, node_id)
                if os.path.isdir(node_path):
                    counts[node_id] = len([f for f in os.listdir(node_path) if f.endswith(".jpg")])
        return jsonify({"status": "ok", "images_by_node": counts,
                         "images_stored": sum(counts.values())}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ── DELETE /images/<node>/<filename> ────────────────────────────
@app.route("/images/<node_id>/<filename>", methods=["DELETE"])
def delete_image(node_id, filename):
    """Delete a specific saved image from its node's subfolder."""
    try:
        node_id = sanitise_node_id(node_id)
        filepath = os.path.join(SAVE_FOLDER, node_id, filename)
        if os.path.exists(filepath):
            os.remove(filepath)
            print(" [-] Deleted: {}/{}".format(node_id, filename))
            return jsonify({"status": "ok", "node": node_id, "deleted": filename}), 200
        return jsonify({"status": "error", "message": "File not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ── Entry point ────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  Smart Water Meter — Multi-Node Image Server")
    print("=" * 60)
    print("  Save folder      : ./{}/<node_id>/".format(SAVE_FOLDER))
    print("  Filename format  : EVT-EF-001_YYYYMMDD_HHMMSS.jpg")
    print()
    print("  Endpoints:")
    print("    POST   /upload                    <- nodes send images here")
    print("    GET    /list                      <- list all images, grouped by node")
    print("    GET    /list?node=EF-001          <- filter by node")
    print("    GET    /images/<node>/<filename>  <- serve saved image")
    print("    GET    /health                    <- health check")
    print("    DELETE /images/<node>/<filename>  <- delete image")
    print()
    print("  Accepted upload formats:")
    print("    1. Multipart form-data  (pi_capture / pipeline)")
    print("    2. Raw Base64 body      (ESP32-CAM)")
    print("    3. Raw JPEG body        (any node)")
    print()
    print("  With Tailscale:")
    print("    Pi uses: http://<laptop-tailscale-ip>:5000")
    print("    No ngrok needed")
    print()
    print("  EvaraFlow dashboard notification:")
    print("    POSTs to {} after every save".format(EVARAFLOW_WEBHOOK_URL))
    print("=" * 60)
    app.run(host="0.0.0.0", port=5000, debug=False)
