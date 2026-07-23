#!/bin/bash
set -euo pipefail

ADB=/opt/android-sdk/cmdline-tools/latest/bin/adb
PORT="${SCRCPY_WEB_PORT:-8000}"

echo "$(date) Health check: Starting..."

while true; do
    BOOT=$("${ADB}" -s emulator-5555 shell getprop sys.boot_completed 2>/dev/null || echo "0")
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}" 2>/dev/null || echo "000")
    echo "$(date) Health: boot=${BOOT} web=${HTTP_CODE}"
    
    # Restart ADB if emulator is not responding
    if [ "${BOOT}" != "1" ]; then
        "${ADB}" start-server 2>/dev/null || true
    fi
    
    sleep 30
done
