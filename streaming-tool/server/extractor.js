const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');

const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';
const SCRCPY_SERVER_PATH = process.env.SCRCPY_SERVER_PATH || '/usr/share/scrcpy/scrcpy-server';
const RTSP_URL = 'rtsp://localhost:8554/mystream';

async function start() {
    console.log('🚀 Starting H.264 Extractor (Max Compatibility Mode)...');

    // 1. Push scrcpy-server to device
    console.log(`📦 Pushing scrcpy-server from ${SCRCPY_SERVER_PATH}...`);
    spawn('adb', ['-s', ADB_DEVICE, 'push', SCRCPY_SERVER_PATH, '/data/local/tmp/scrcpy-server.jar']).on('close', (code) => {
        if (code !== 0) {
            console.error('❌ Failed to push scrcpy-server');
            process.exit(1);
        }
        
        // 2. Start scrcpy-server on device
        console.log('🎬 Starting scrcpy-server on device...');
        // We use default profile and lower resolution to avoid MediaCodec errors
        const args = [
            '-s', ADB_DEVICE, 
            'shell', 
            'CLASSPATH=/data/local/tmp/scrcpy-server.jar', 
            'app_process', 
            '/', 
            'com.genymobile.scrcpy.Server', 
            '2.4', 
            'log_level=info',
            'video_bit_rate=2000000',
            'max_fps=30',
            'max_size=720', // Lower resolution for better stability
            'tunnel_forward=true',
            'audio=false',
            'control=false',
            'cleanup=true',
            'raw_stream=true'
            // Removed video_codec_options=profile=66 as it caused 0x80001001
        ];

        const serverProc = spawn('adb', args);

        serverProc.stdout.on('data', (data) => console.log(`[scrcpy-server] ${data}`));
        serverProc.stderr.on('data', (data) => console.error(`[scrcpy-server-err] ${data}`));

        // 3. Forward the video socket
        setTimeout(() => {
            console.log('🔌 Forwarding video socket...');
            spawn('adb', ['-s', ADB_DEVICE, 'forward', 'tcp:27183', 'localabstract:scrcpy']).on('close', (code) => {
                if (code !== 0) {
                    console.error('❌ Failed to forward socket');
                    return;
                }

                // 4. Connect to the socket and pipe to ffmpeg
                connectAndPipe();
            });
        }, 3000);
    });
}

function connectAndPipe() {
    console.log('🔗 Connecting to video socket...');
    const socket = net.connect(27183, '127.0.0.1');
    
    const ffmpeg = spawn('ffmpeg', [
        '-fflags', 'nobuffer',
        '-i', 'pipe:0',
        '-c:v', 'copy',
        '-f', 'rtsp',
        '-rtsp_transport', 'tcp',
        RTSP_URL
    ]);

    ffmpeg.stderr.on('data', (data) => {
        const msg = data.toString();
        if (msg.includes('Error') || msg.includes('fatal')) {
            console.error(`[ffmpeg-err] ${msg}`);
        }
    });

    ffmpeg.on('close', (code) => {
        console.log(`🎬 FFmpeg exited with code ${code}`);
        process.exit(code);
    });

    socket.pipe(ffmpeg.stdin);

    socket.on('error', (err) => {
        console.error('❌ Socket error:', err);
        process.exit(1);
    });

    socket.on('close', () => {
        console.log('🔌 Socket closed');
        process.exit(0);
    });
}

start();
