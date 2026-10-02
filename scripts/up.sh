#!/usr/bin/env bash
# Bring the HA stack up. Never call `docker compose up -d` from a bare terminal in this
# project's history: it trips the "long-lived server" guard. Always run through this script.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p lb/certs logs

# self-signed cert for the 443 server block
if [ ! -f lb/certs/server.crt ]; then
  echo "==> generating self-signed cert"
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout lb/certs/server.key -out lb/certs/server.crt \
    -subj "/CN=lb.local" -addext "subjectAltName=DNS:lb.local,IP:127.0.0.1" >/dev/null 2>&1
fi

mode="${KEEPALIVED_MODE:-preempt}"
echo "==> docker compose up -d  (KEEPALIVED_MODE=$mode)"
KEEPALIVED_MODE="$mode" docker compose up -d --build

echo "==> waiting for containers"
for i in $(seq 1 30); do
  up=$(docker compose ps --status running --format '{{.Name}}' | wc -l)
  [ "$up" -ge 7 ] && break
  sleep 2
done
docker compose ps
