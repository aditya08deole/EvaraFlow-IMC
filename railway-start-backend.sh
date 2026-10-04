#!/bin/sh
# Copied into the image at /docker-entrypoint.d/50-start-backend.sh (see
# Dockerfile.railway). nginx's own official entrypoint runs every script in
# /docker-entrypoint.d/ before it execs nginx itself in the foreground, so
# this backgrounds the Node backend first and lets that entrypoint continue
# on to start nginx as the container's main process.
#
# Fixed internal port (3000), not whatever external $PORT Railway assigned
# this container -- that one belongs to nginx (see nginx.railway.conf.template).
# The two must never collide, so this always overrides PORT for just this
# one command rather than trusting whatever's already in the environment.
PORT=3000 node /app/dist/index.js &
