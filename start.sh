#!/bin/bash
set -euo pipefail

echo "Cloud Android Phone"
echo "===================="

if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is required. Install it first."
    exit 1
fi

[ -e /dev/kvm ] && sudo chmod 666 /dev/kvm 2>/dev/null || true

# Pull images
echo "[1/5] Pulling Docker images..."
docker pull shmayro/dockerify-android:latest
docker pull shmayro/scrcpy-web:latest

# Start Android emulator
echo "[2/5] Starting Android emulator..."
docker run -d \
    --name dockerify-android \
    --privileged \
    --device /dev/kvm \
    -p 5555:5555 \
    -e DNS=one.one.one.one \
    -e RAM_SIZE=4096 \
    -e SCREEN_RESOLUTION=720x1280 \
    -e ROOT_SETUP=1 \
    -e GAPPS_SETUP=1 \
    -e ARM_TRANSLATION=1 \
    shmayro/dockerify-android:latest

# Start scrcpy-web
echo "[3/5] Starting web interface (scrcpy-web)..."
sleep 10
docker run -d \
    --name scrcpy-web \
    --privileged \
    -p 8000:8000 \
    --link dockerify-android \
    shmayro/scrcpy-web:latest sh -c \
    "adb connect dockerify-android:5555 && npm start"

# Wait for boot
echo "[4/5] Waiting for Android to boot..."
for i in $(seq 1 450); do
    BOOT=$(docker exec dockerify-android adb -s emulator-5555 shell getprop sys.boot_completed 2>/dev/null || echo "0")
    if [ "${BOOT}" = "1" ]; then
        echo "Android boot completed after $((i * 2))s"
        break
    fi
    [ $((i % 30)) -eq 0 ] && echo "  ... booting ($((i * 2))s)"
    sleep 2
done

# Apply optimizations
docker exec dockerify-android adb shell settings put global window_animation_scale 0 2>/dev/null || true
docker exec dockerify-android adb shell settings put global transition_animation_scale 0 2>/dev/null || true
docker exec dockerify-android adb shell settings put global animator_duration_scale 0 2>/dev/null || true
docker exec dockerify-android adb shell settings put system screen_off_timeout 2147483647 2>/dev/null || true

# Start tunnel
echo "[5/5] Creating public tunnel..."
npm install -g localtunnel 2>/dev/null || npm install -g localtunnel --force 2>/dev/null || true

if command -v lt &>/dev/null; then
    TUNNEL_URL=$(lt --port 8000 2>/dev/null | grep -oP 'https://[^ ]+' | head -1)
fi

TUNNEL_URL="${TUNNEL_URL:-http://localhost:8000}"

echo ""
echo "=========================================="
echo "  CLOUD ANDROID PHONE IS READY!"
echo "=========================================="
echo ""
echo "  URL: ${TUNNEL_URL}"
echo "  Local: http://localhost:8000"
echo "  Android: API 34 (Android 14)"
echo ""
echo "  Open the URL in your browser to use your phone!"
echo "  Stop: ./stop.sh"
echo "=========================================="
