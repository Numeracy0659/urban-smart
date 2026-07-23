#!/bin/bash
set -euo pipefail

echo "Stopping Cloud Android Phone..."
docker stop scrcpy-web 2>/dev/null && docker rm scrcpy-web 2>/dev/null || true
docker stop dockerify-android 2>/dev/null && docker rm dockerify-android 2>/dev/null || true
pkill -f "nport.*8000" 2>/dev/null || true
echo "Stopped. Clean."
