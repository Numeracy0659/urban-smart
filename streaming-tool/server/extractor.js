const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');

const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';
const SCRCPY_SERVER_PATH = process.env.SCRCPY_SERVER_PATH || '/usr/share/scrcpy/scrcpy-server';
const RTSP_URL = 'rtsp://localhost:8554/mystream';

async function start() {
    console.log('🚀 Starting H.264 Extractor (v2.x Compatible)...');

    // 1. Push scrcpy-server to device
    console.log(`📦 Pushing scrcpy-server from ${SCRCPY_SERVER_PATH}...`);
    spawn('adb', ['-s', ADB_DEVICE, 'push', SCRCPY_SERVER_PATH, '/data/local/tmp/scrcpy-server.jar']).on('close', (code) => {
        if (code !== 0) {
            console.error('❌ Failed to push scrcpy-server');
            process.exit(1);
        }
        
        // 2. Start scrcpy-server on device
        console.log('🎬 Starting scrcpy-server on device...');
        // Arguments for scrcpy 2.x
        const args = [
            '-s', ADB_DEVICE, 
            'shell', 
            'CLASSPATH=/data/local/tmp/scrcpy-server.jar', 
            'app_process', 
            '/', 
            'com.genymobile.scrcpy.Server', 
            '2.4', // version
            'log_level=info',
            'max_size=1280',
            'video_bit_rate=2000000',
            'max_fps=30',
            'locked_video_orientation=-1',
            'tunnel_forward=true',
            'control=true',
            'display_id=0',
            'show_touches=false',
            'stay_awake=true',
            'power_off_on_close=false',
            'clipboard_autosync=false',
            'downsize_on_error=true',
            'cleanup=true',
            'power_on=true',
            'send_device_meta=true',
            'send_dummy_byte=true',
            'send_codec_meta=true',
            'send_frame_meta=true'
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
    
    let metadataRead = false;
    let ffmpeg = null;

    function startFfmpeg() {
        ffmpeg = spawn('ffmpeg', [
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
    }

    startFfmpeg();

    let buffer = Buffer.alloc(0);

    socket.on('data', (data) => {
        buffer = Buffer.concat([buffer, data]);

        if (!metadataRead) {
            // scrcpy 2.0+ metadata:
            // 1 byte: dummy
            // 64 bytes: device name
            // 4 bytes: width
            // 4 bytes: height
            // 4 bytes: codec id (in some versions)
            if (buffer.length >= 73) {
                console.log('✅ Received scrcpy metadata');
                const dummy = buffer[0];
                const deviceName = buffer.slice(1, 65).toString().replace(/\0/g, '');
                const width = buffer.readUInt32BE(65);
                const height = buffer.readUInt32BE(69);
                console.log(`📱 Device: ${deviceName}, Resolution: ${width}x${height}`);
                
                buffer = buffer.slice(73);
                // Some versions send 4 more bytes for codec
                if (buffer.length >= 4 && buffer[0] !== 0 && buffer[0] !== 0 && buffer[0] !== 0 && buffer[0] !== 1) {
                     buffer = buffer.slice(4);
                }
                
                metadataRead = true;
            }
        }

        if (metadataRead) {
            processPackets();
        }
    });

    function processPackets() {
        // scrcpy 2.0+ packet header:
        // 8 bytes: PTS (or 0xFFFFFFFFFFFFFFFF if no PTS)
        // 4 bytes: packet size
        while (buffer.length >= 12) {
            // Check for Annex B start code as a safety measure
            // If we see 00 00 00 01 at the start, it might be a raw stream (1.x)
            if (buffer[0] === 0 && buffer[1] === 0 && buffer[2] === 0 && buffer[3] === 1) {
                ffmpeg.stdin.write(buffer);
                buffer = Buffer.alloc(0);
                return;
            }

            const pts = buffer.readBigUInt64BE(0);
            const size = buffer.readUInt32BE(8);
            
            if (size > 10 * 1024 * 1024) { // 10MB safety limit
                console.error('❌ Invalid packet size:', size);
                buffer = buffer.slice(1); // Try to resync
                return;
            }

            if (buffer.length >= 12 + size) {
                const packet = buffer.slice(12, 12 + size);
                ffmpeg.stdin.write(packet);
                buffer = buffer.slice(12 + size);
            } else {
                break; // Wait for more data
            }
        }
    }

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
