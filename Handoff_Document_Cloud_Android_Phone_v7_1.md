# 📱 Handoff: Cloud Android Phone v7.1 (Dual-Mode Edition)

## 📋 Project Overview
This project provides a high-performance, low-latency Android 14 cloud phone accessible via a web browser. It utilizes `scrcpy-server` for H.264 extraction and a dual-mode streaming pipeline (WebRTC + WebSocket) for maximum reliability through tunnels.

## 🔗 Critical Links & Credentials
*   **GitHub Repository**: [https://github.com/Numeracy0659/urban-smart](https://github.com/Numeracy0659/urban-smart)
*   **GitHub PAT**: `[REDACTED_BY_PUSH_PROTECTION]` (Use the provided credential)
*   **Latest Workflow Run**: [Run #30603915501](https://github.com/Numeracy0659/urban-smart/actions/runs/30603915501) (In Progress)

## 🏗️ Technical Architecture (v7.1)
The system has been significantly hardened to handle tunnel-induced network instability:

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Extraction** | `scrcpy-server` | Direct socket extraction in `raw_stream` mode (Annex B). |
| **Primary Stream** | **WebRTC (TCP)** | Ultra-low latency via MediaMTX (v1.9.0). |
| **Fallback Stream** | **WebSocket H.264** | Uses `jMuxer` on the frontend for bulletproof reliability. |
| **Process Manager** | `supervisor.js` | Manages MediaMTX, Extractor, and Control Server. |
| **Multiplexer** | Custom TCP Proxy | Routes HTTP/WS/WebRTC traffic through a single port (8000). |
| **Control** | Persistent ADB Shell | Reduces input lag by keeping a live shell connection. |

## 🛠️ Key Files
*   `streaming-tool/supervisor.js`: The central orchestrator and TCP multiplexer.
*   `streaming-tool/server/extractor.js`: Handles dual-broadcasting to RTSP and WebSockets.
*   `streaming-tool/server/index.js`: Manages the signaling proxy and persistent ADB shell.
*   `streaming-tool/client/index.html`: The "Dual-Mode" frontend with automatic protocol fallback.
*   `streaming-tool/server/mediamtx.yml`: Hardened config for MediaMTX v1.9.0.

## 🚀 Current Status & Next Steps
1.  **Monitor Build**: The current GitHub Action (Run #30603915501) is the final production build.
2.  **Extract URL**: Once the "Start nport Tunnel" step completes, retrieve the `https://*.nport.link` URL from the logs or the `debug-logs-and-url` artifact.
3.  **Verify Fallback**:
    *   Open the link. The UI should show **"Attempting WebRTC..."**.
    *   If WebRTC connects, the badge will show **"Stream: WebRTC (TCP)"**.
    *   If it fails (common on first load or restricted networks), it will instantly switch to **"Stream: WebSocket (H.264)"**.
4.  **Device Setup**: The emulator is Android 14. **Termux** and **F-Droid** are pre-installed. The session is configured for **6 hours**.

## ⚠️ Known Fixes Applied
*   **MediaCodec 0x80001001**: Fixed by lowering resolution to 720p and using the default profile.
*   **MediaMTX Crash**: Resolved by removing the unsupported `webrtcICETCP` field from the YAML.
*   **SDP Modification**: The signaling proxy now dynamically rewrites ICE candidates to match the `nport` tunnel URL.

---
*Handed off by Manus v7.1 Agent.*
