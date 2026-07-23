#!/bin/bash
set -euo pipefail

echo "Cloud Android Phone v3.0"
echo "=========================="

if ! command -v docker &>/dev/null; then
    echo "Docker required. Install: https://docs.docker.com/get-docker/"
    exit 1
fi

[ -e /dev/kvm ] && sudo chmod 666 /dev/kvm 2>/dev/null || true

echo "Building image..."
docker build -t cloud-android-phone:latest .

echo "Starting container..."
docker run -d \
    --name cloud-phone \
    --privileged \
    --device /dev/kvm:/dev/kvm \
    -p 8000:8000 \
    -p 5555:5555 \
    -e DISPLAY_WIDTH=720 \
    -e DISPLAY_HEIGHT=1280 \
    -e RAM_SIZE=4096 \
    -e SCRCPY_WEB_PORT=8000 \
    -e ARM_TRANSLATION=1 \
    -e ROOT_SETUP=1 \
    -e GAPPS_SETUP=1 \
    -e SESSION_MAX_HOURS=6 \
    cloud-android-phone:latest

echo "Waiting for boot..."
for i in $(seq 1 300); do
    BOOT=$(docker exec cloud-phone /opt/android-sdk/cmdline-tools/latest/bin/adb -s emulator-5555 shell getprop sys.boot_completed 2>/dev/null || echo "0")
    if [ "${BOOT}" = "1" ]; then
        echo "Boot complete after $((i * 2))s"
        break
    fi
    [ $i -eq 90 ] && echo "  ... 3 min"
    [ $i -eq 180 ] && echo "  ... 6 min"
    sleep 2
done

TUNNEL_URL="http://localhost:8000"

# Start NPort tunnel
npm install -g nport 2>/dev/null || npm install -g --force nport
SUB="caphone-$(date +%s | sha256sum | head -c 6)"
nport 8000 -s "${SUB}" > /tmp/nport-cp.log 2>&1 &

for i in $(seq 1 30); do
    sleep 3
    if grep -q "nport.link" /tmp/nport-cp.log 2>/dev/null; then
        TUNNEL_URL=$(grep -oP 'https://[a-zA-Z0-9.-]+\.nport\.link' /tmp/nport-cp.log | head -1)
        break
    fi
done

echo ""
echo "=========================================="
echo "  READY! URL: ${TUNNEL_URL}"
echo "  Open in any browser to use your Cloud Android Phone"
echo "=========================================="
echo ""
echo "Stop:  ./stop.sh"
echo "Logs:  docker logs -f cloud-phone"
