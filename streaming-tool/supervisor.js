const { spawn } = require('child_process');
const net = require('net');
const http = require('http');
const path = require('path');
const fs = require('fs');

const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';
const PORT = 8000;
const MEDIAMTX_PORT = 8889;
const CONTROL_PORT = 8001;

console.log('🏗️ Starting Process Supervisor (v7.1)...');

let processes = {
    mediamtx: null,
    control: null,
    extractor: null
};

// 1. Start MediaMTX
function startMediaMTX() {
    console.log('📡 Starting MediaMTX...');
    processes.mediamtx = spawn('./bin/mediamtx', ['./server/mediamtx.yml'], {
        stdio: 'inherit'
    });
    processes.mediamtx.on('close', (code) => {
        console.log(`⚠️ MediaMTX exited with code ${code}, restarting...`);
        setTimeout(startMediaMTX, 2000);
    });
}

// 2. Start Node.js Control Server
function startControlServer() {
    console.log('🎮 Starting Control Server...');
    processes.control = spawn('node', ['./server/index.js'], {
        env: { ...process.env, PORT: CONTROL_PORT, ADB_DEVICE },
        stdio: 'inherit'
    });
    processes.control.on('close', (code) => {
        console.log(`⚠️ Control Server exited with code ${code}, restarting...`);
        setTimeout(startControlServer, 2000);
    });
}

// 3. Start H.264 Extractor
function startExtractor() {
    console.log('🎥 Starting H.264 Extractor...');
    processes.extractor = spawn('node', ['./server/extractor.js'], {
        env: { ...process.env, ADB_DEVICE },
        stdio: 'inherit'
    });
    processes.extractor.on('close', (code) => {
        console.log(`⚠️ Extractor exited with code ${code}, restarting...`);
        setTimeout(startExtractor, 2000);
    });
}

// 4. Port Multiplexer (Port 8000 -> Control or MediaMTX)
function startMultiplexer() {
    console.log(`🔌 Starting Multiplexer on port ${PORT}...`);
    
    const server = net.createServer((clientSocket) => {
        clientSocket.once('data', (data) => {
            const firstLine = data.toString().split('\n')[0];
            // HTTP methods or WebSocket handshake
            const isHttp = /^(GET|POST|PUT|DELETE|OPTIONS|HEAD|PATCH)/.test(firstLine);
            
            const targetPort = isHttp ? CONTROL_PORT : MEDIAMTX_PORT;
            
            const targetSocket = net.connect(targetPort, '127.0.0.1', () => {
                targetSocket.write(data);
                clientSocket.pipe(targetSocket).pipe(clientSocket);
            });
            
            targetSocket.on('error', (err) => {
                console.error(`❌ Multiplexer target error (${targetPort}):`, err.message);
                clientSocket.destroy();
            });
            
            clientSocket.on('error', (err) => {
                targetSocket.destroy();
            });
        });
    });
    
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`✅ Multiplexer listening on port ${PORT}`);
    });
}

// 5. Health Monitor
setInterval(() => {
    const status = {
        mediamtx: processes.mediamtx && !processes.mediamtx.killed,
        control: processes.control && !processes.control.killed,
        extractor: processes.extractor && !processes.extractor.killed
    };
    console.log(`💓 Heartbeat: MediaMTX=${status.mediamtx}, Control=${status.control}, Extractor=${status.extractor}`);
}, 30000);

// Main Execution
startMediaMTX();
setTimeout(startControlServer, 2000);
setTimeout(startExtractor, 5000);
startMultiplexer();

// Keep alive
process.on('uncaughtException', (err) => {
    console.error('💥 Uncaught Exception:', err);
});
