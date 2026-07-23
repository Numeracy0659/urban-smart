#!/bin/bash
set -euo pipefail

echo "Cloud Android Phone v3.0"
echo "=========================="

if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker required"
    exit 1
fi

[ -e /dev/kvm ] && sudo chmod 666 /dev/kvm 2>/dev/null || true

# Pull images
echo "Pulling images..."
docker pull shmayro/dockerify-android:latest
docker pull shmayro/scrcpy-web:latest

# Start Android emulator
echo "Starting Android emulator..."
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
echo "Starting web interface..."
sleep 10
docker run -d \
    --name scrcpy-web \
    --privileged \
    -p 8000:8000 \
    --link dockerify-android \
    shmayro/scrcpy-web:latest sh -c \
    "adb connect dockerify-android:5555 && npm start"

# Wait for boot
echo "Waiting for Android to boot (10-15 min on first run)..."
for i in $(seq 1 450); do
    BOOT=$(docker exec dockerify-android adb -s emulator-5555 shell getprop sys.boot_completed 2>/dev/null || echo "0")
    if [ "${BOOT}" = "1" ]; then
        echo "Android boot completed after $((i * 2))s"
        break
    fi
    [ $((i % 30)) -eq 0 ] && echo "  ... $((i * 2))s"
    sleep 2
done

# Start NPort
echo "Starting tunnel..."
npm install -g nport 2>/dev/null || true
SUB="caphone-$(date +%s | sha256sum | head -c 6)"
nohup nport 8000 -s "${SUB}" > /tmp/nport-cp.log 2>&1 &

for i in $(seq 1 30); do
    sleep 3
    if grep -q "nport.link" /tmp/nport-cp.log 2>/dev/null; then
        TUNNEL_URL=$(grep -oP 'https://[a-zA-Z0-9.-]+\.nport\.link' /tmp/nport-cp.log | head -1)
        [ -n "${TUNNEL_URL}" ] && break
    fi
done
TUNNEL_URL="${TUNNEL_URL:-http://localhost:8000}"

echo ""
echo "=========================================="
echo "  READY! URL: ${TUNNEL_URL}"
echo "=========================================="
echo "Stop: ./stop.sh"
