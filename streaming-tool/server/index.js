const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const { spawn, execSync } = require('child_process');
const bodyParser = require('body-parser');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 8000;
const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';

app.use(bodyParser.json());
app.use(bodyParser.text({ type: 'application/sdp' }));
app.use(express.static(path.join(__dirname, '../client')));

// --- Persistent ADB Shell for Control ---
let adbShell = null;

function startAdbShell() {
    console.log('🔗 Starting persistent ADB shell...');
    adbShell = spawn('adb', ['-s', ADB_DEVICE, 'shell']);
    
    adbShell.on('close', (code) => {
        console.log(`⚠️ ADB shell closed with code ${code}, restarting...`);
        setTimeout(startAdbShell, 1000);
    });

    adbShell.stderr.on('data', (data) => {
        console.error(`[adb-shell-err] ${data}`);
    });
}

function sendAdbCommand(cmd) {
    if (adbShell && adbShell.stdin.writable) {
        adbShell.stdin.write(cmd + '\n');
        return true;
    }
    return false;
}

startAdbShell();

// --- WebRTC Signaling Proxy with SDP Modification ---
app.post('/whep', (req, res) => {
    const options = {
        hostname: 'localhost',
        port: 8889,
        path: '/mystream/whep',
        method: 'POST',
        headers: {
            'Content-Type': 'application/sdp'
        }
    };

    const proxyReq = http.request(options, (proxyRes) => {
        let body = '';
        proxyRes.on('data', (chunk) => body += chunk);
        proxyRes.on('end', () => {
            // Modify SDP to handle the tunnel URL
            const host = req.headers.host; // e.g., user-123.nport.link
            let modifiedSdp = body;
            
            if (host) {
                console.log(`🔧 Modifying SDP for host: ${host}`);
                // Replace internal IP with tunnel host
                // WHEP answers usually contain ICE candidates
                // We need to replace the IP and ensure the port is 443 (HTTPS)
                // a=candidate:1 1 TCP 2128604671 127.0.0.1 8889 typ host ...
                modifiedSdp = body.replace(/127\.0\.0\.1 8889/g, `${host} 443`);
                modifiedSdp = modifiedSdp.replace(/0\.0\.0\.0 8889/g, `${host} 443`);
                
                // Also handle the c= line
                modifiedSdp = modifiedSdp.replace(/c=IN IP4 127\.0\.0\.1/g, `c=IN IP4 0.0.0.0`);
            }
            
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            res.end(modifiedSdp);
        });
    });

    proxyReq.on('error', (e) => {
        console.error(`Problem with signaling proxy: ${e.message}`);
        res.status(500).send(e.message);
    });

    proxyReq.write(req.body);
    proxyReq.end();
});

// --- ADB Control Endpoints ---
app.post('/api/control/tap', (req, res) => {
    const { x, y } = req.body;
    if (sendAdbCommand(`input tap ${x} ${y}`)) {
        res.json({ status: 'ok' });
    } else {
        res.status(500).json({ error: 'ADB shell not available' });
    }
});

app.post('/api/control/swipe', (req, res) => {
    const { x1, y1, x2, y2, duration } = req.body;
    if (sendAdbCommand(`input swipe ${x1} ${y1} ${x2} ${y2} ${duration || 300}`)) {
        res.json({ status: 'ok' });
    } else {
        res.status(500).json({ error: 'ADB shell not available' });
    }
});

app.post('/api/control/key', (req, res) => {
    const { code } = req.body;
    if (sendAdbCommand(`input keyevent ${code}`)) {
        res.json({ status: 'ok' });
    } else {
        res.status(500).json({ error: 'ADB shell not available' });
    }
});

app.post('/api/control/text', (req, res) => {
    const { text } = req.body;
    const escaped = text.replace(/ /g, '%s').replace(/"/g, '\\"');
    if (sendAdbCommand(`input text "${escaped}"`)) {
        res.json({ status: 'ok' });
    } else {
        res.status(500).json({ error: 'ADB shell not available' });
    }
});

app.get('/api/info/resolution', (req, res) => {
    try {
        const output = execSync(`adb -s ${ADB_DEVICE} shell wm size`).toString();
        const match = output.match(/Physical size: (\d+)x(\d+)/);
        if (match) {
            res.json({ width: parseInt(match[1]), height: parseInt(match[2]) });
        } else {
            res.status(500).json({ error: 'Could not parse resolution' });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- ADB Shell WebSocket ---
wss.on('connection', (ws) => {
    console.log('New WebSocket connection for ADB shell');
    const shell = spawn('adb', ['-s', ADB_DEVICE, 'shell']);
    shell.stdout.on('data', (data) => ws.send(data.toString()));
    shell.stderr.on('data', (data) => ws.send(data.toString()));
    ws.on('message', (message) => shell.stdin.write(message + '\n'));
    ws.on('close', () => shell.kill());
});

server.listen(PORT, () => {
    console.log(`🚀 Control server listening on port ${PORT}`);
});
