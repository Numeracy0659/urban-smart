#!/bin/bash

# 1. Environment Setup
ADB_DEVICE="localhost:5555"
export PATH=$PATH:$(pwd)/bin

echo "🚀 Starting Cloud Android Phone Streaming Tool (v7.0)..."

# 2. Clean up old processes
pkill -f mediamtx || true
pkill -f "node index.js" || true
pkill -f "node supervisor.js" || true
pkill -f "node extractor.js" || true
pkill -f scrcpy || true
pkill -f ffmpeg || true
pkill -f screenrecord || true

# 3. Ensure dependencies
cd server
npm install > /dev/null 2>&1
cd ..

# 4. Check for MediaMTX
if [ ! -f "./bin/mediamtx" ]; then
    echo "📡 Downloading MediaMTX..."
    mkdir -p bin
    curl -L -o mediamtx.tar.gz https://github.com/bluenviron/mediamtx/releases/download/v1.9.0/mediamtx_v1.9.0_linux_amd64.tar.gz
    tar -xzf mediamtx.tar.gz -C bin mediamtx
    rm mediamtx.tar.gz
fi

# 5. Ensure ADB is connected (wait for it if needed)
echo "🔌 Connecting to ADB..."
adb connect $ADB_DEVICE || true

# 6. Start the Supervisor
echo "🏗️ Launching Supervisor..."
nohup node supervisor.js > supervisor.log 2>&1 &
disown

echo "✅ System initialized! Logs are in supervisor.log"
echo "   Access via port 8000 (proxied through nport)"
