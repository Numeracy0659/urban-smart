#!/bin/bash
set -euo pipefail

MAX_HOURS="${SESSION_MAX_HOURS:-6}"
MAX_SECONDS=$((MAX_HOURS * 3600))
START_TIME=$(date +%s)

echo "$(date) Session Monitor: Max = ${MAX_HOURS}h"

while true; do
    sleep 60
    
    ELAPSED=$(($(date +%s) - START_TIME))
    REMAINING=$((MAX_SECONDS - ELAPSED))
    
    if [ "${REMAINING}" -le 0 ]; then
        echo "$(date) TIME LIMIT REACHED - initiating shutdown"
        
        # Stop services gracefully
        supervisorctl stop nport healthcheck session-monitor 2>/dev/null || true
        sleep 5
        supervisorctl stop ws-scrcpy 2>/dev/null || true
        sleep 5
        
        # Backup session data
        /usr/local/bin/backup-session.sh 2>/dev/null || true
        
        # Stop emulator
        supervisorctl stop emulator 2>/dev/null || true
        
        echo "$(date) Session ended cleanly"
        exit 0
    fi
    
    HOURS=$((REMAINING / 3600))
    MINUTES=$(((REMAINING % 3600) / 60))
    echo "$(date) Remaining: ${HOURS}h ${MINUTES}m"
done
