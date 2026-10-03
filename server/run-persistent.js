/**
 * Local-dev process supervisor for dist/index.js — exists because the
 * ad-hoc `node dist/index.js` terminal session run during the EVT-EF-002
 * incident (EVARAFLOW_GROUND_TRUTH.md D-015/D-017) got killed and restarted
 * by hand more than once, each time losing whatever the device published
 * during the gap (QoS 0, no persistent session — a message published while
 * nothing is connected is gone forever, not queued).
 *
 * This does NOT replace deploying to Railway (server/README.md) — it only
 * makes a local run survive the child process crashing, not this terminal
 * being closed or this machine sleeping. It's a stopgap for local dev, not
 * a substitute for an always-on host.
 *
 * Usage: node run-persistent.js   (from server/, after `npm run build`)
 */

const { spawn } = require("child_process");

const MIN_BACKOFF_MS = 2000;
const MAX_BACKOFF_MS = 30000;
let backoff = MIN_BACKOFF_MS;
let shuttingDown = false;

function log(msg) {
  console.log(`[supervisor ${new Date().toISOString()}] ${msg}`);
}

function start() {
  log("starting dist/index.js");
  const child = spawn(process.execPath, ["dist/index.js"], {
    stdio: "inherit",
    env: process.env,
  });

  const startedAt = Date.now();

  child.on("exit", (code, signal) => {
    if (shuttingDown) return;
    const ranMs = Date.now() - startedAt;
    log(`dist/index.js exited (code=${code}, signal=${signal}) after ${Math.round(ranMs / 1000)}s`);

    // A process that stayed up a while before dying gets a fast retry;
    // one that crashes immediately on every attempt backs off instead of
    // hot-looping.
    backoff = ranMs > 60_000 ? MIN_BACKOFF_MS : Math.min(backoff * 2, MAX_BACKOFF_MS);
    log(`restarting in ${backoff}ms`);
    setTimeout(start, backoff);
  });
}

process.on("SIGINT", () => {
  shuttingDown = true;
  log("received SIGINT, shutting down supervisor (child will exit with it)");
  process.exit(0);
});

start();
