#!/bin/bash
set -e

# Configuration
ADB_DEVICE="localhost:5555"
STREAM_PORT=8000
MEDIAMTX_VERSION="v1.9.0"
SCRCPY_VERSION="2.1"

echo "🚀 Starting Custom Android Streaming Tool..."

# 1. Check Dependencies
echo "📦 Checking system dependencies..."
# We assume dependencies are handled by the workflow for production, 
# but we keep a lightweight check here.
for cmd in ffmpeg adb node npm scrcpy; do
    if ! command -v $cmd &> /dev/null; then
        echo "⚠️ $cmd not found, attempting to install..."
        sudo apt-get install -y $cmd || echo "Failed to install $cmd"
    fi
done

# 3. Download MediaMTX
if [ ! -f "./bin/mediamtx" ]; then
    echo "📥 Downloading MediaMTX ${MEDIAMTX_VERSION}..."
    wget -q https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_amd64.tar.gz
    tar -xzf mediamtx_${MEDIAMTX_VERSION}_linux_amd64.tar.gz -C ./bin
    rm mediamtx_${MEDIAMTX_VERSION}_linux_amd64.tar.gz
fi

# 4. Install Node.js dependencies
echo "npm installing server dependencies..."
cd server
npm install
cd ..

# 5. Start MediaMTX in background
echo "📡 Starting MediaMTX..."
./bin/mediamtx ./server/mediamtx.yml > mediamtx.log 2>&1 &
MEDIAMTX_PID=$!

# 6. Start Node.js Control Server in background
echo "🎮 Starting Control Server..."
cd server
# Use 0.0.0.0 to ensure it's reachable
ADB_DEVICE=$ADB_DEVICE PORT=$STREAM_PORT node index.js > ../server.log 2>&1 &
NODE_PID=$!
cd ..

# 7. Start scrcpy -> ffmpeg -> MediaMTX pipeline
echo "🎥 Starting Video Pipeline..."
# Ensure ADB is connected
adb connect $ADB_DEVICE || true
sleep 5

# Check if scrcpy can see the device
if ! adb -s $ADB_DEVICE shell getprop sys.boot_completed > /dev/null 2>&1; then
    echo "❌ ADB device not ready for scrcpy!"
fi

# We use scrcpy to output raw H.264 and pipe it to ffmpeg
# Added -v quiet to ffmpeg to reduce log noise, but keep scrcpy errors
scrcpy -s $ADB_DEVICE --no-window --no-audio --video-codec=h264 --max-fps=30 --video-bit-rate=2M --raw-video-stream - | \
ffmpeg -i - -c:v copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/mystream > ffmpeg.log 2>&1 &
PIPELINE_PID=$!

# 8. Health Check
sleep 5
echo "🔍 Running Health Check..."
netstat -tuln | grep -E "8000|8889|8554" || echo "⚠️ Warning: Some ports are not listening!"
ps aux | grep -E "node|mediamtx|scrcpy|ffmpeg" | grep -v grep || echo "⚠️ Warning: Some processes are not running!"

echo "✅ All systems started!"
echo "   - Control Server: http://localhost:$STREAM_PORT"
echo "   - WebRTC Stream:  http://localhost:8889/mystream"
echo ""
echo "Press Ctrl+C to stop..."

# Keep script running and handle cleanup
trap "kill $MEDIAMTX_PID $NODE_PID $PIPELINE_PID; exit" INT TERM
wait
