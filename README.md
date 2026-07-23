# Cloud Android Phone v3.0

A complete Android phone running in your browser — on-demand, secure, ephemeral, zero cost.

## Architecture

Built on Alpine Linux with minimal footprint. Uses ws-scrcpy for H.264 video streaming over WebSocket (60fps, multi-touch, clipboard, keyboard, APK drag-and-drop). NPort creates instant HTTPS tunnels for public access.

## Features

| Feature | Details |
|---------|---------|
| Android 14 (API 34) | Pixel 6 device profile |
| Browser Streaming | ws-scrcpy — H.264 over WebSocket, 60fps |
| Public URL | NPort tunnel — instant `https://*.nport.link` |
| Root Access | Magisk pre-installed (optional) |
| Google Apps | PICO GAPPS (optional) |
| Session Duration | Up to 6 hours (configurable) |
| Zero Cost | Runs on GitHub Actions free tier |

## Quick Start

1. Push to GitHub
2. Go to **Actions** tab
3. Click **"Run workflow"** → **Start**
4. Wait for boot (~5-10 minutes)
5. Open the URL printed in the workflow logs

## Local Usage

```bash
chmod +x start.sh stop.sh scripts/*.sh
./start.sh
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DISPLAY_WIDTH` | 720 | Screen width (px) |
| `DISPLAY_HEIGHT` | 1280 | Screen height (px) |
| `RAM_SIZE` | 4096 | Emulator RAM (MB) |
| `SESSION_MAX_HOURS` | 6 | Max session duration |

## License

MIT
