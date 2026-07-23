#!/bin/bash
set -euo pipefail

echo "🧹 Stopping Cloud Android Phone..."

mkdir -p /tmp/cloud-phone-backup
docker exec cloud-phone tar czf - /home/androidusr/backup > /tmp/cloud-phone-backup/session.tar.gz 2>/dev/null || true
docker exec cloud-phone /opt/android-sdk/platform-tools/adb -s emulator-5555 shell pm list packages > /tmp/cloud-phone-backup/packages.txt 2>/dev/null || true

pkill -f "nport.*8000" 2>/dev/null || true
docker stop cloud-phone 2>/dev/null || true
docker rm cloud-phone 2>/dev/null || true

echo "✓ Stopped. Backup in /tmp/cloud-phone-backup/"
