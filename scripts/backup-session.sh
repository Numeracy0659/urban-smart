#!/bin/bash
set -euo pipefail

BACKUP_DIR="/home/androidusr/backup"
ADB=/opt/android-sdk/cmdline-tools/latest/bin/adb
SESSION_ID="${SESSION_ID:-$(date +%s | sha256sum | head -c 8)}"

mkdir -p "${BACKUP_DIR}"

echo "$(date) Backup: Starting [${SESSION_ID}]"

# Save device settings
"${ADB}" -s emulator-5555 shell settings list global > "${BACKUP_DIR}/settings-global.txt" 2>/dev/null || true
"${ADB}" -s emulator-5555 shell pm list packages > "${BACKUP_DIR}/packages.txt" 2>/dev/null || true

# Save AVD data if available
if [ -d /root/.android/avd ]; then
    tar czf "${BACKUP_DIR}/avd-data.tar.gz" -C /root/.android avd/ 2>/dev/null || true
fi

# Write manifest
cat > "${BACKUP_DIR}/session-manifest.json" <<MANIFEST
{
  "session_id": "${SESSION_ID}",
  "backup_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "android_version": "14 (API 34)",
  "device": "pixel_6"
}
MANIFEST

echo "$(date) Backup: Complete"
