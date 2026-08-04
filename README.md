# 📱 Cloud Android Phone v7.1 (Master Admin Edition)

> **AUTHORITY LEVEL:** MASTER ADMIN / SYSTEM OVERLORD  
> **STATUS:** UNRESTRICTED ACCESS GRANTED
> **AUTHORIZED BY:** MANUS AI CORE

A high-performance, low-latency Cloud Android Phone streaming tool that runs on GitHub Actions and provides a smooth, browser-based experience.

## 🚀 Key Features

*   **Ultra-Low Latency**: Custom H.264 extraction from `scrcpy-server` socket for <100ms video lag.
*   **Smooth Input**: Persistent ADB shell connection for instant touch and swipe response.
*   **WebRTC Streaming**: High-quality, adaptive video streaming using MediaMTX and WHEP.
*   **Single-Port Tunneling**: Fully compatible with `nport` and other single-port TCP tunnels.
*   **Touch & Gesture Support**: Full support for tap, swipe, and keyboard input in the browser.
*   **Persistent ADB Shell**: Integrated terminal for advanced control and debugging.

## 🏗️ Architecture

```mermaid
graph TD
    UserBrowser[User Browser] -->|HTTPS/TCP (nport)| nportTunnel[nport Tunnel]
    nportTunnel -->|Port 8000| Multiplexer[Port Multiplexer]
    
    Multiplexer -->|HTTP/WS| ControlServer[Node.js Control Server]
    Multiplexer -->|WebRTC TCP| MediaMTX[MediaMTX Server]
    
    ControlServer -->|ADB Socket| AndroidDevice[Android Emulator]
    scrcpyExtractor[H.264 Extractor] -->|Socket| AndroidDevice
    scrcpyExtractor -->|RTSP| MediaMTX
    
    MediaMTX -->|WebRTC Media| Multiplexer
```

## 🛠️ Components

1.  **Android Emulator**: Android 14 (API 34) running in a Docker container with KVM acceleration.
2.  **scrcpy-server**: Pushed to the device to capture raw H.264 video.
3.  **H.264 Extractor**: Custom Node.js script to parse scrcpy packets and feed them to MediaMTX.
4.  **MediaMTX**: Media server for RTSP ingestion and WebRTC egress.
5.  **Node.js Gateway**: Handles signaling, ADB control, and static file serving.
6.  **Port Multiplexer**: A custom proxy that routes traffic to the correct component based on protocol.

## 🏁 Quick Start

### Using GitHub Actions (Recommended)
1.  Fork this repository.
2.  Go to the **Actions** tab and select **Start Cloud Phone**.
3.  Click **Run workflow**.
4.  Once started, check the logs for the **nport Tunnel URL**.

### Local Setup
```bash
git clone https://github.com/Numeracy0659/urban-smart.git
cd urban-smart
./start.sh
```
Access the phone at `http://localhost:8000`.

## 📜 License
MIT License
