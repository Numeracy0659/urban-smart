#!/bin/bash
set -euo pipefail
PORT="${SCRCPY_WEB_PORT:-8000}"
SESSION_ID="${SESSION_ID:-$(date +%s | sha256sum | head -c 6)}"
SUBDOMAIN="caphone-${SESSION_ID}"
echo "$(date) Tunnel: Waiting for ws-scrcpy..."
for i in $(seq 1 60); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}" 2>/dev/null | grep -qE "^[2-4]"; then
        echo "$(date) Tunnel: Server ready"
        break
    fi
    sleep 3
done
echo "$(date) Tunnel: Starting NPort..."
exec nport "${PORT}" -s "${SUBDOMAIN}" 2>&1
