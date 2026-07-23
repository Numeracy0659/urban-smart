# Cloud Android Phone

Full Android phone in your browser — on-demand, secure, ephemeral, zero cost.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Runner                     │
│  ┌──────────────────┐    ┌──────────────┐                   │
│  │ dockerify-android │←→ │ scrcpy-web    │                   │
│  │ (Android 14)      │    │ (H.264/WS)    │                   │
│  │ + ARM Translation │    │ Port 8000     │                   │
│  │ + Root + GAPPS    │    │               │                   │
│  └──────────────────┘    └──────┬───────┘                   │
│                                  │                          │
│                          ┌───────▼───────┐                   │
│                          │  bore.pub      │                   │
│                          │  (Tunnel)      │                   │
│                          └───────┬───────┘                   │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                            ┌──────▼──────┐
                            │  Your Phone  │
                            │  (Browser)   │
                            └─────────────┘
```

## Features

| Feature | Details |
|---------|---------|
| Android 14 (API 34) | Pixel 6 device profile |
| Browser Streaming | scrcpy-web — H.264 over WebSocket, 60fps |
| Public URL | bore.pub tunnel — instant public URL |
| Root Access | Magisk pre-installed (toggle) |
| Google Apps | PICO GAPPS (toggle) |
| ARM Translation | Run ARM apps on x86 (toggle) |
| Session Duration | Up to 6 hours (configurable) |
| Zero Cost | GitHub Actions free tier |

## Quick Start

1. Go to **Actions** tab in your repository
2. Click **"Run workflow"** → select **"start"**
3. Configure options (root, GAPPS, resolution)
4. Wait 10-15 minutes for boot
5. Open the URL from the workflow logs or download the artifact

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `action` | start | `start` or `stop` |
| `resolution` | 720x1280 | Screen resolution |
| `ram_mb` | 4096 | RAM in MB |
| `enable_root` | true | Enable Magisk root |
| `enable_gapps` | true | Enable PICO GAPPS |
| `enable_arm` | true | ARM translation for ARM apps |
| `session_hours` | 6 | Max session duration |

## How It Works

1. **Workflow triggers** — You manually start the workflow from GitHub Actions
2. **KVM enabled** — Hardware acceleration for the Android emulator
3. **Docker images pulled** — Pre-built Android and streaming images
4. **Android boots** — Emulator initializes with your configured options
5. **scrcpy-web starts** — H.264 WebSocket streaming on port 8000
6. **Tunnel created** — bore.pub exposes port 8000 to the internet
7. **Access your phone** — Open the URL in any browser
8. **Session alive** — Workflow monitors for up to 6 hours
9. **Auto cleanup** — When session ends, everything is destroyed

## Local Usage

```bash
# Quick start
chmod +x start.sh stop.sh
./start.sh

# Stop
./stop.sh
```

## Technology Stack

- [shmayro/dockerify-android](https://github.com/Shmayro/dockerify-android) — Android emulator in Docker
- [shmayro/scrcpy-web](https://github.com/Shmayro/ws-scrcpy-docker) — Browser streaming
- [codetalkio/expose-tunnel](https://github.com/marketplace/actions/expose-tunnel) — bore.pub tunnel
- [ekzhang/bore](https://github.com/ekzhang/bore) — Tunneling service
- [ws-scrcpy](https://github.com/NetrisTV/ws-scrcpy) — WebSocket scrcpy client

## License

MIT
