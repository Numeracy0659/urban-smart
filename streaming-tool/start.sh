#!/bin/bash

# 1. Environment Setup
ADB_DEVICE="localhost:5555"
STREAM_PORT=8000
WEBRTC_PORT=8889
RTSP_PORT=8554

echo "🚀 Starting Custom Streaming Tool..."

# 2. Prepare Directories
mkdir -p bin logs
export PATH=$PATH:$(pwd)/bin

# 3. Check for MediaMTX
if [ ! -f "./bin/mediamtx" ]; then
    echo "❌ MediaMTX binary not found in bin/!"
    # The workflow should have downloaded it, but let's be safe
fi

# 4. Clean up old processes
pkill -f mediamtx || true
pkill -f "node index.js" || true
pkill -f scrcpy || true
pkill -f ffmpeg || true

# 5. Start MediaMTX in background
echo "📡 Starting MediaMTX..."
nohup ./bin/mediamtx ./server/mediamtx.yml > mediamtx.log 2>&1 &
disown

# 6. Start Node.js Control Server in background
echo "🎮 Starting Control Server..."
cd server
# Ensure dependencies are there
npm install express ws body-parser
nohup node index.js > ../server.log 2>&1 &
disown
cd ..

# 7. Start scrcpy -> ffmpeg -> MediaMTX pipeline
echo "🎥 Starting Video Pipeline..."
# Ensure ADB is connected
adb connect $ADB_DEVICE || true
sleep 10

# Check if scrcpy can see the device
if ! adb -s $ADB_DEVICE shell getprop sys.boot_completed > /dev/null 2>&1; then
    echo "⚠️ Warning: ADB device not fully ready for scrcpy yet, but proceeding..."
fi

# We use scrcpy to output raw H.264 and pipe it to ffmpeg
# Added nohup to ensure it survives the shell exit
nohup sh -c "scrcpy -s $ADB_DEVICE --no-window --no-audio --video-codec=h264 --max-fps=30 --video-bit-rate=2M --raw-video-stream | ffmpeg -i - -c:v copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/mystream" > ffmpeg.log 2>&1 &
disown

# 8. Health Check
sleep 10
echo "🔍 Running Health Check..."
netstat -tuln | grep -E "8000|8889|8554" || echo "⚠️ Warning: Some ports are not listening!"
ps aux | grep -E "node|mediamtx|scrcpy|ffmpeg" | grep -v grep || echo "⚠️ Warning: Some processes are not running!"

echo "✅ All systems started!"
echo "   - Control Server: http://localhost:$STREAM_PORT"
echo "   - WebRTC Stream:  http://localhost:8889/mystream"
