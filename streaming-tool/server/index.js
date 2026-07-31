const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const { spawn, execSync, exec } = require('child_process');
const bodyParser = require('body-parser');
const fs = require('fs');
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ noServer: true });
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
    adbShell.on('close', () => setTimeout(startAdbShell, 1000));
}

function sendAdbCommand(cmd) {
    if (adbShell && adbShell.stdin.writable) {
        adbShell.stdin.write(cmd + '\n');
        return true;
    }
    return false;
}

startAdbShell();

// --- WebSocket H.264 Stream (jMuxer) ---
const videoWss = new WebSocket.Server({ noServer: true });
function broadcastVideo(data) {
    videoWss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
}

// Handle WebSocket upgrades
server.on('upgrade', (request, socket, head) => {
    const pathname = new URL(request.url, `http://${request.headers.host}`).pathname;
    if (pathname === '/api/shell') {
        wss.handleUpgrade(request, socket, head, (ws) => {
            wss.emit('connection', ws, request);
        });
    } else if (pathname === '/api/video') {
        videoWss.handleUpgrade(request, socket, head, (ws) => {
            videoWss.emit('connection', ws, request);
        });
    } else {
        socket.destroy();
    }
});

// --- WebRTC Signaling Proxy ---
app.post('/whep', (req, res) => {
    const options = {
        hostname: 'localhost',
        port: 8889,
        path: '/mystream/whep',
        method: 'POST',
        headers: { 'Content-Type': 'application/sdp' }
    };
    const proxyReq = http.request(options, (proxyRes) => {
        let body = '';
        proxyRes.on('data', (chunk) => body += chunk);
        proxyRes.on('end', () => {
            const host = req.headers.host;
            let modifiedSdp = body;
            if (host) {
                modifiedSdp = body.replace(/127\.0\.0\.1 8889/g, `${host} 443`);
                modifiedSdp = modifiedSdp.replace(/0\.0\.0\.0 8889/g, `${host} 443`);
                modifiedSdp = modifiedSdp.replace(/localhost 8889/g, `${host} 443`);
                modifiedSdp = modifiedSdp.replace(/c=IN IP4 127\.0\.0\.1/g, `c=IN IP4 0.0.0.0`);
            }
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            res.end(modifiedSdp);
        });
    });
    proxyReq.on('error', (e) => res.status(500).send(e.message));
    proxyReq.write(req.body);
    proxyReq.end();
});

// --- ADB Control Endpoints ---
app.post('/api/control/tap', (req, res) => {
    const { x, y } = req.body;
    sendAdbCommand(`input tap ${x} ${y}`);
    res.json({ status: 'ok' });
});

app.post('/api/control/swipe', (req, res) => {
    const { x1, y1, x2, y2, duration } = req.body;
    sendAdbCommand(`input swipe ${x1} ${y1} ${x2} ${y2} ${duration || 300}`);
    res.json({ status: 'ok' });
});

app.post('/api/control/key', (req, res) => {
    const { code } = req.body;
    sendAdbCommand(`input keyevent ${code}`);
    res.json({ status: 'ok' });
});

app.get('/api/info/resolution', (req, res) => {
    try {
        const output = execSync(`adb -s ${ADB_DEVICE} shell wm size`).toString();
        const match = output.match(/Physical size: (\d+)x(\d+)/);
        if (match) res.json({ width: parseInt(match[1]), height: parseInt(match[2]) });
        else res.status(500).json({ error: 'Parse error' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- Advanced Customization: Frida Installation ---
app.post('/api/admin/install-frida', (req, res) => {
    const version = req.body.version || '17.16.4';
    const arch = 'android-x86_64';
    const url = `https://github.com/frida/frida/releases/download/${version}/frida-server-${version}-${arch}.xz`;
    const localPath = `/tmp/frida-server.xz`;
    const decompressedPath = `/tmp/frida-server`;
    
    console.log(`🚀 Installing Frida ${version} (${arch})...`);
    
    exec(`wget -O ${localPath} ${url} && xz -d -f ${localPath} && chmod +x ${decompressedPath} && adb -s ${ADB_DEVICE} push ${decompressedPath} /data/local/tmp/frida-server && adb -s ${ADB_DEVICE} shell "chmod 755 /data/local/tmp/frida-server" && adb -s ${ADB_DEVICE} shell "/data/local/tmp/frida-server &"`, (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ Frida installation failed: ${error.message}`);
            return res.status(500).json({ error: error.message, stderr });
        }
        console.log(`✅ Frida installed and started!`);
        res.json({ status: 'ok', stdout });
    });
});

// --- Advanced Customization: APK Installation ---
app.post('/api/admin/install-apk', (req, res) => {
    const { url } = req.body;
    if (!url) return res.status(400).json({ error: 'URL is required' });
    
    const localPath = `/tmp/app.apk`;
    console.log(`🚀 Installing APK from ${url}...`);
    
    exec(`wget -O ${localPath} "${url}" && adb -s ${ADB_DEVICE} install -r ${localPath}`, (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ APK installation failed: ${error.message}`);
            return res.status(500).json({ error: error.message, stderr });
        }
        console.log(`✅ APK installed!`);
        res.json({ status: 'ok', stdout });
    });
});

// --- Advanced Customization: Generic Shell ---
app.post('/api/admin/shell', (req, res) => {
    const { command } = req.body;
    if (!command) return res.status(400).json({ error: 'Command is required' });
    
    console.log(`🚀 Executing shell command: ${command}`);
    
    exec(command, (error, stdout, stderr) => {
        res.json({ stdout, stderr, error: error ? error.message : null });
    });
});

// --- ADB Shell WebSocket ---
wss.on('connection', (ws) => {
    const shell = spawn('adb', ['-s', ADB_DEVICE, 'shell']);
    shell.stdout.on('data', (data) => ws.send(data.toString()));
    shell.stderr.on('data', (data) => ws.send(data.toString()));
    ws.on('message', (message) => shell.stdin.write(message + '\n'));
    ws.on('close', () => shell.kill());
});

server.listen(PORT, () => {
    console.log(`🚀 Control & Video Server listening on port ${PORT}`);
});

module.exports = { broadcastVideo };
