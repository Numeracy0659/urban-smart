#!/bin/bash
set -e

# Configuration
ADB_DEVICE="localhost:5555"
STREAM_PORT=8000
MEDIAMTX_VERSION="v1.9.0"
SCRCPY_VERSION="2.1"

echo "🚀 Starting Custom Android Streaming Tool..."

# 1. Install Dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update -y
sudo apt-get install -y ffmpeg adb nodejs npm wget curl libsdl2-2.0-0

# 2. Install scrcpy (if not present)
if ! command -v scrcpy &> /dev/null; then
    echo "📥 Installing scrcpy..."
    sudo apt-get install -y scrcpy || {
        # Fallback to manual install if apt version is too old
        wget -q https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}/scrcpy-server-v${SCRCPY_VERSION}
        sudo mv scrcpy-server-v${SCRCPY_VERSION} /usr/local/bin/scrcpy-server
    }
fi

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
ADB_DEVICE=$ADB_DEVICE PORT=$STREAM_PORT node index.js > ../server.log 2>&1 &
NODE_PID=$!
cd ..

# 7. Start scrcpy -> ffmpeg -> MediaMTX pipeline
echo "🎥 Starting Video Pipeline..."
# Ensure ADB is connected
adb connect $ADB_DEVICE || true
sleep 2

# We use scrcpy to output raw H.264 and pipe it to ffmpeg
# ffmpeg then pushes it to MediaMTX via RTSP
# Note: scrcpy 2.0+ supports --raw-video-stream
# If scrcpy version is < 2.0, we might need a different approach, but we'll try this first.
scrcpy -s $ADB_DEVICE --no-window --no-audio --video-codec=h264 --max-fps=30 --video-bit-rate=2M --raw-video-stream - | \
ffmpeg -i - -c:v copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/mystream > ffmpeg.log 2>&1 &
PIPELINE_PID=$!

echo "✅ All systems started!"
echo "   - Control Server: http://localhost:$STREAM_PORT"
echo "   - WebRTC Stream:  http://localhost:8889/mystream"
echo ""
echo "Press Ctrl+C to stop..."

# Keep script running and handle cleanup
trap "kill $MEDIAMTX_PID $NODE_PID $PIPELINE_PID; exit" INT TERM
wait
