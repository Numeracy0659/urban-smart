const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');
const WebSocket = require('ws');

const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';
const SCRCPY_SERVER_PATH = process.env.SCRCPY_SERVER_PATH || '/usr/share/scrcpy/scrcpy-server';
const RTSP_URL = 'rtsp://localhost:8554/mystream';
const WS_VIDEO_URL = `ws://localhost:8001/api/video`;

let wsClient = null;

function connectWS() {
    wsClient = new WebSocket(WS_VIDEO_URL);
    wsClient.on('error', () => setTimeout(connectWS, 1000));
    wsClient.on('close', () => setTimeout(connectWS, 1000));
}

async function start() {
    console.log('🚀 Starting H.264 Extractor (Dual Stream Mode)...');
    connectWS();

    spawn('adb', ['-s', ADB_DEVICE, 'push', SCRCPY_SERVER_PATH, '/data/local/tmp/scrcpy-server.jar']).on('close', (code) => {
        if (code !== 0) process.exit(1);
        
        const args = [
            '-s', ADB_DEVICE, 'shell', 'CLASSPATH=/data/local/tmp/scrcpy-server.jar', 
            'app_process', '/', 'com.genymobile.scrcpy.Server', '2.4', 
            'log_level=info', 'video_bit_rate=2000000', 'max_fps=30', 'max_size=720',
            'tunnel_forward=true', 'audio=false', 'control=false', 'cleanup=true', 'raw_stream=true'
        ];

        spawn('adb', args);

        setTimeout(() => {
            spawn('adb', ['-s', ADB_DEVICE, 'forward', 'tcp:27183', 'localabstract:scrcpy']).on('close', (code) => {
                if (code !== 0) return;
                connectAndPipe();
            });
        }, 3000);
    });
}

function connectAndPipe() {
    const socket = net.connect(27183, '127.0.0.1');
    
    const ffmpeg = spawn('ffmpeg', [
        '-fflags', 'nobuffer', '-i', 'pipe:0',
        '-c:v', 'copy', '-f', 'rtsp', '-rtsp_transport', 'tcp', RTSP_URL
    ]);

    socket.on('data', (data) => {
        // Broadcast to WebSocket for jMuxer
        if (wsClient && wsClient.readyState === WebSocket.OPEN) {
            wsClient.send(data);
        }
        // Pipe to FFmpeg for WebRTC/MediaMTX
        ffmpeg.stdin.write(data);
    });

    socket.on('error', () => process.exit(1));
    socket.on('close', () => process.exit(0));
}

start();
