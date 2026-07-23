#!/bin/bash
set -euo pipefail

ADB=/opt/android-sdk/platform-tools/adb
PORT="${SCRCPY_WEB_PORT:-8000}"

echo "$(date) ws-scrcpy: Waiting for ADB device..."
while ! "${ADB}" -s emulator-5555 shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do
    sleep 5
done
echo "$(date) ws-scrcpy: Android boot completed"

"${ADB}" -s emulator-5555 tcpip 5555 2>/dev/null || true
sleep 2

cd /opt/ws-scrcpy
export ADBHOST=emulator-5555
exec node dist/index.js --port "${PORT}" --host 0.0.0.0 2>&1
