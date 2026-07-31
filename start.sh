#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Cloud Android Phone — CUSTOM WEBRTC EDITION
# ═══════════════════════════════════════════════════════════════════════════════

echo "🚀 Starting Cloud Android Phone (WebRTC Edition)..."

# 1. Start Android Emulator (Docker)
if [ "$(docker ps -q -f name=dockerify-android)" ]; then
    echo "📱 Emulator container already running."
else
    echo "📱 Starting Emulator container..."
    docker run -d \
        --name dockerify-android \
        --privileged \
        --device /dev/kvm \
        -p 5555:5555 \
        -e RAM_SIZE=4096 \
        -e SCREEN_RESOLUTION=720x1280 \
        shmayro/dockerify-android:latest
fi

# 2. Wait for ADB
echo "🔌 Waiting for ADB..."
until adb connect localhost:5555 > /dev/null 2>&1; do
    sleep 2
done

# 3. Start Streaming Tool
echo "🎥 Starting WebRTC Streaming Tool..."
cd streaming-tool
chmod +x start.sh
./start.sh

# 4. Create Tunnel (Optional)
if command -v nport &>/dev/null; then
    echo "🌐 Starting nport tunnel..."
    nport 8000 --language en > tunnel.log 2>&1 &
    sleep 5
    TUNNEL_URL=$(grep -o 'https://[-a-z0-9.]*.nport.link' tunnel.log | head -n 1)
    echo "🔗 Public URL: ${TUNNEL_URL}"
fi

echo "✅ All systems started!"
echo "🏠 Local Access: http://localhost:8000"
