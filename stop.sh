#!/bin/bash
set -euo pipefail

echo "Stopping Cloud Android Phone..."
docker stop scrcpy-web 2>/dev/null && docker rm scrcpy-web 2>/dev/null || true
docker stop dockerify-android 2>/dev/null && docker rm dockerify-android 2>/dev/null || true
pkill -f "nport" 2>/dev/null || true
pkill -f "lt --port" 2>/dev/null || true
pkill -f "bore" 2>/dev/null || true
docker system prune -f 2>/dev/null || true
echo "All services stopped and cleaned up."
