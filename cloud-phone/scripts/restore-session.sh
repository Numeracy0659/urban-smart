#!/bin/bash
set -euo pipefail

BACKUP_DIR="/home/androidusr/backup"

if [ ! -f "${BACKUP_DIR}/session-manifest.json" ]; then
    echo "$(date) Restore: No previous session - fresh start"
    exit 0
fi

SESSION_ID=$(jq -r '.session_id' "${BACKUP_DIR}/session-manifest.json" 2>/dev/null || echo "unknown")
echo "$(date) Restore: Found session ${SESSION_ID}"

AVD_BACKUP=$(ls "${BACKUP_DIR}"/avd-data*.tar.gz 2>/dev/null | head -1)
if [ -n "${AVD_BACKUP}" ] && [ -f "${AVD_BACKUP}" ]; then
    tar xzf "${AVD_BACKUP}" -C /root/.android/ 2>/dev/null || true
    echo "  AVD data restored"
fi

echo "$(date) Restore: Complete"
