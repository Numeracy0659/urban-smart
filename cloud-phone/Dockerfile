###############################################################################
# Cloud Android Phone - Production Dockerfile
# PhantomLink Operations v2.0
###############################################################################

FROM node:20-bookworm-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/NetrisTV/ws-scrcpy.git && \
    cd ws-scrcpy && \
    npm install && \
    npx tsc -b

FROM ubuntu:22.04

LABEL maintainer="PhantomLink Operations" \
      description="Cloud Android Phone - Full Android in a container" \
      version="2.0.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PATH="/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:/opt/android-sdk/tools:${PATH}" \
    DISPLAY_WIDTH=720 \
    DISPLAY_HEIGHT=1280 \
    RAM_SIZE=4096 \
    SCRCPY_WEB_PORT=8000 \
    ADB_PORT=5555 \
    ARM_TRANSLATION=1 \
    ROOT_SETUP=1 \
    GAPPS_SETUP=1 \
    SESSION_MAX_HOURS=6

# System Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget jq gnupg2 gpg-agent \
    ca-certificates dnsutils iputils-ping \
    qemu-kvm libvirt-clients bridge-utils \
    xvfb x11-xserver-utils x11-utils \
    openjdk-11-jdk-headless \
    lib32stdc++6 lib32gcc1 lib32z1 \
    alsa-utils \
    supervisor \
    tar gzip \
    procps net-tools sudo unzip && \
    rm -rf /var/lib/apt/lists/*

# Non-Root User
RUN groupadd -r androidusr && \
    useradd -r -g androidusr -d /home/androidusr -s /bin/bash -m androidusr && \
    usermod -aG sudo androidusr && \
    echo "androidusr ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/androidusr/{logs,backup,data} && \
    chown -R androidusr:androidusr /home/androidusr

# Android SDK
RUN mkdir -p /opt/android-sdk && \
    cd /opt/android-sdk && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip && \
    unzip -q cmdline-tools.zip && \
    mv cmdline-tools latest && \
    rm cmdline-tools.zip && \
    chmod -R 755 /opt/android-sdk

RUN yes | sdkmanager --licenses 2>/dev/null || true && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-34" \
        "emulator" \
        "system-images;android-34;google_apis;x86_64" \
        "extras;google;google_play_services" 2>&1 | tail -5

# Create AVD
RUN avdmanager create avd \
    --force \
    --name cloud_phone \
    --package "system-images;android-34;google_apis;x86_64" \
    --device "pixel_6" \
    --tag google_apis \
    --abi x86_64 && \
    echo "hw.lcd.width=720" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "hw.lcd.height=1280" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "hw.lcd.density=320" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "hw.ramSize=4096" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "hw.gpu.enabled=yes" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "hw.gpu.mode=host" >> /root/.android/avd/cloud_phone.avd/config.ini && \
    echo "sdcard.size=2G" >> /root/.android/avd/cloud_phone.avd/config.ini

# Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ws-scrcpy
COPY --from=builder /build/ws-scrcpy /opt/ws-scrcpy
WORKDIR /opt/ws-scrcpy
RUN npm install --production 2>/dev/null || true

# NPort
RUN npm install -g nport@latest

# Project Files
COPY scripts/ /usr/local/bin/
COPY config/ /etc/cloud-phone/

RUN chmod +x /usr/local/bin/*.sh && \
    chown -R androidusr:androidusr /usr/local/bin /opt/ws-scrcpy /etc/cloud-phone

EXPOSE 8000 5555

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

CMD ["supervisord", "-c", "/etc/cloud-phone/supervisord.conf", "-n"]
