# Cloud Android Phone v3.0

Full Android phone in your browser — on-demand, secure, ephemeral, zero cost.

## Architecture

Uses **shmayro/dockerify-android** (Android 14 emulator with ARM translation, root, GAPPS) + **shmayro/scrcpy-web** (H.264 WebSocket streaming to browser) + **NPort** (instant HTTPS tunnel). All running on GitHub Actions free tier with KVM acceleration.

## Features

| Feature | Details |
|---------|---------|
| Android 14 (API 34) | Pixel 6 device profile |
| Browser Streaming | scrcpy-web — H.264 over WebSocket, 60fps |
| Public URL | NPort tunnel — instant `https://*.nport.link` |
| Root Access | Magisk pre-installed (toggle) |
| Google Apps | PICO GAPPS (toggle) |
| ARM Translation | Run ARM apps on x86 (toggle) |
| Session Duration | Up to 6 hours (configurable) |
| Zero Cost | GitHub Actions free tier |

## Quick Start

1. Go to **Actions** tab
2. Click **"Run workflow"** → **start**
3. Configure options (root, GAPPS, resolution)
4. Wait 10-15 minutes for boot
5. Open the URL from the workflow logs

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

## Local Usage

```bash
chmod +x start.sh stop.sh
./start.sh
```

## Credits

- [shmayro/dockerify-android](https://github.com/Shmayro/dockerify-android) — Android emulator
- [shmayro/ws-scrcpy-docker](https://github.com/Shmayro/ws-scrcpy-docker) — Web streaming
- [nport](https://github.com/tuanngocptn/nport) — HTTP tunneling

## License

MIT
