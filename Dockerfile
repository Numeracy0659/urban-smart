###############################################################################
# Cloud Android Phone v3.0 - Ultimate Production Dockerfile
# Alpine 3.19 + Android Emulator + ws-scrcpy + NPort
###############################################################################

FROM alpine:3.19

LABEL maintainer="Cloud Android Phone" version="3.0.0"

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk \
    PATH="/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:${PATH}" \
    DISPLAY_WIDTH=720 DISPLAY_HEIGHT=1280 RAM_SIZE=4096 \
    SCRCPY_WEB_PORT=8000 ADB_PORT=5555 \
    ARM_TRANSLATION=1 ROOT_SETUP=1 GAPPS_SETUP=1 SESSION_MAX_HOURS=6

# ─── System Dependencies (Alpine correct package names) ───
RUN apk update && apk add --no-cache \
    bash curl wget jq gnupg gpg-agent \
    ca-certificates \
    qemu-system-x86_64 libvirt-daemon bridge-utils \
    openjdk11-jdk-headless \
    alsa-lib alsa-utils \
    supervisor tar gzip procps net-tools sudo unzip shadow \
    xvfb x11vnc xterm mesa-dri-gallium mesa-egl mesa-gbm mesa-osmesa \
    nodejs npm git python3 make g++ linux-headers build-base \
    openjdk11-jre-headless && \
    rm -rf /var/cache/apk/*

# ─── Install NPort ───
RUN npm install -g nport

# ─── Install Android SDK (Minimal) ───
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd /tmp && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip && \
    unzip -q cmdline-tools.zip && \
    mv cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm cmdline-tools.zip

# ─── Accept Licenses and Install SDK Components ───
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "emulator" \
    "system-images;android-34;google_apis;x86_64" > /dev/null 2>&1

# ─── Create AVD (Android Virtual Device) ───
RUN ${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager create avd \
    --force \
    --name cloud_phone \
    --package "system-images;android-34;google_apis;x86_64" \
    --device "pixel_6" \
    --tag google_apis \
    --abi x86_64 && \
    cat >> /root/.android/avd/cloud_phone.avd/config.ini <<CONFIG
hw.lcd.width=720
hw.lcd.height=1280
hw.lcd.density=320
hw.ramSize=4096
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.camera.back=emulated
hw.camera.front=emulated
hw.audioInput=yes
hw.audioOutput=yes
CONFIG

# ─── Create Android User ───
RUN adduser -D androidusr && \
    addgroup androidusr sudo && \
    echo "androidusr ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/androidusr/{logs,backup,data} && \
    chown -R androidusr:androidusr /home/androidusr

# ─── Install ws-scrcpy ───
RUN git clone --depth 1 https://github.com/NetrisTV/ws-scrcpy.git /opt/ws-scrcpy && \
    cd /opt/ws-scrcpy && \
    npm install --omit=dev && \
    npx tsc -b

# ─── Copy Config and Scripts ───
COPY config/ /etc/cloud-phone/
COPY scripts/ /usr/local/bin/

RUN chmod +x /usr/local/bin/*.sh && \
    chown -R androidusr:androidusr /usr/local/bin /opt/ws-scrcpy /etc/cloud-phone /opt/android-sdk

# ─── Expose Ports ───
EXPOSE 8000 5555

# ─── Health Check ───
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -sf http://localhost:8000 || exit 1

# ─── Start ───
CMD ["supervisord", "-c", "/etc/cloud-phone/supervisord.conf", "-n"]
