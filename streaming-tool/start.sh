#!/bin/bash

# 1. Environment Setup
ADB_DEVICE="localhost:5555"
STREAM_PORT=8000
WEBRTC_PORT=8889
RTSP_PORT=8554

echo "🚀 Starting Custom Streaming Tool..."

# 2. Prepare Directories
mkdir -p logs
# Ensure bin is in path
export PATH=$PATH:$(pwd)/bin

# 3. Clean up old processes
pkill -f mediamtx || true
pkill -f "node index.js" || true
pkill -f scrcpy || true
pkill -f ffmpeg || true
pkill -f screenrecord || true

# 4. Start MediaMTX in background
echo "📡 Starting MediaMTX..."
# Check if binary exists
if [ -f "./bin/mediamtx" ]; then
    nohup ./bin/mediamtx ./server/mediamtx.yml > mediamtx.log 2>&1 &
    disown
else
    echo "❌ MediaMTX binary not found in $(pwd)/bin/!"
fi

# 5. Start Node.js Control Server in background
echo "🎮 Starting Control Server..."
cd server
# Ensure dependencies are there
npm install express ws body-parser > /dev/null 2>&1
nohup node index.js > ../server.log 2>&1 &
disown
cd ..

# 6. Start Video Pipeline
echo "🎥 Starting Video Pipeline..."
# Ensure ADB is connected
adb connect $ADB_DEVICE || true
sleep 15

# Use adb screenrecord to output raw H.264 and pipe it to ffmpeg
# This is much more reliable than scrcpy in headless environments
nohup sh -c "adb -s $ADB_DEVICE shell screenrecord --output-format=h264 --size 720x1280 --bit-rate 2M - | ffmpeg -i - -c:v copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/mystream" > ffmpeg.log 2>&1 &
disown

# 7. Health Check
sleep 10
echo "🔍 Running Health Check..."
netstat -tuln | grep -E "8000|8889|8554" || echo "⚠️ Warning: Some ports are not listening!"
ps aux | grep -E "node|mediamtx|ffmpeg|adb" | grep -v grep

echo "✅ All systems started!"
echo "   - Control Server: http://localhost:$STREAM_PORT"
echo "   - WebRTC Stream:  http://localhost:8889/mystream"
