const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const { spawn, execSync } = require('child_process');
const bodyParser = require('body-parser');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 8000;
const ADB_DEVICE = process.env.ADB_DEVICE || 'localhost:5555';

app.use(bodyParser.json());
app.use(bodyParser.text({ type: 'application/sdp' }));
app.use(express.static(path.join(__dirname, '../client')));

// --- WebRTC Signaling Proxy ---
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
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res, { end: true });
    });

    proxyReq.on('error', (e) => {
        console.error(`Problem with request: ${e.message}`);
        res.status(500).send(e.message);
    });

    proxyReq.write(req.body);
    proxyReq.end();
});

// --- ADB Control Endpoints ---

// Handle touch/click events
app.post('/api/control/tap', (req, res) => {
    const { x, y } = req.body;
    try {
        execSync(`adb -s ${ADB_DEVICE} shell input tap ${x} ${y}`);
        res.json({ status: 'ok' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/control/swipe', (req, res) => {
    const { x1, y1, x2, y2, duration } = req.body;
    try {
        execSync(`adb -s ${ADB_DEVICE} shell input swipe ${x1} ${y1} ${x2} ${y2} ${duration || 300}`);
        res.json({ status: 'ok' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/control/key', (req, res) => {
    const { code } = req.body;
    try {
        execSync(`adb -s ${ADB_DEVICE} shell input keyevent ${code}`);
        res.json({ status: 'ok' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/control/text', (req, res) => {
    const { text } = req.body;
    try {
        const escaped = text.replace(/ /g, '%s').replace(/"/g, '\\"');
        execSync(`adb -s ${ADB_DEVICE} shell input text "${escaped}"`);
        res.json({ status: 'ok' });
    } catch (err) {
        res.status(500).json({ error: err.message });
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
    
    shell.stdout.on('data', (data) => {
        ws.send(data.toString());
    });
    
    shell.stderr.on('data', (data) => {
        ws.send(data.toString());
    });
    
    ws.on('message', (message) => {
        shell.stdin.write(message + '\n');
    });
    
    ws.on('close', () => {
        shell.kill();
    });
});

server.listen(PORT, () => {
    console.log(`Control server listening on port ${PORT}`);
    console.log(`Targeting ADB device: ${ADB_DEVICE}`);
});
