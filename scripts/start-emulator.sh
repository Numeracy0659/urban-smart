#!/bin/bash
set -euo pipefail

ADB=/opt/android-sdk/cmdline-tools/latest/bin/adb
EMULATOR=/opt/android-sdk/emulator/emulator

# Start ADB server
"${ADB}" start-server 2>&1 | tee -a /home/androidusr/logs/adb.log

# Check KVM
if [ -e /dev/kvm ]; then
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    echo "$(date) KVM: Available"
    ACCEL_FLAG="-accel on"
else
    echo "$(date) KVM: Not available (software rendering)"
    ACCEL_FLAG="-accel off"
fi

# Start emulator
exec "${EMULATOR}" \
    -avd cloud_phone \
    -no-window \
    -no-snapshot-load \
    -no-snapshot-save \
    -no-audio \
    -no-boot-anim \
    -no-skin \
    -qemu \
    ${ACCEL_FLAG} \
    -show-kernel 2>&1
