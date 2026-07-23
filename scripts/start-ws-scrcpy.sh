#!/bin/bash
set -euo pipefail

ADB=/opt/android-sdk/cmdline-tools/latest/bin/adb
PORT="${SCRCPY_WEB_PORT:-8000}"

echo "$(date) ws-scrcpy: Waiting for ADB device..."

# Wait for emulator to boot
while true; do
    BOOT=$(su -s /bin/sh androidusr -c "${ADB} -s emulator-5555 shell getprop sys.boot_completed" 2>/dev/null || echo "0")
    if [ "${BOOT}" = "1" ]; then
        echo "$(date) ws-scrcpy: Android boot completed"
        break
    fi
    sleep 5
done

# Setup ADB TCP connection
"${ADB}" -s emulator-5555 tcpip 5555 2>/dev/null || true
sleep 2

# Start ws-scrcpy
cd /opt/ws-scrcpy
export WS_SCRCPY_CONFIG=/etc/cloud-phone/ws-scrcpy-config.json
exec node dist/index.js --port "${PORT}" --host 0.0.0.0 2>&1
