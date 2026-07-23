###############################################################################
# Cloud Android Phone - Ultimate Production Dockerfile
# Built on Alpine Android + ws-scrcpy + NPort
###############################################################################

FROM alpine:3.18 AS base

# System Dependencies
RUN apk update && apk add --no-cache \
    bash curl wget jq gnupg2 gpg-agent \
    ca-certificates \
    qemu-system-x86_64 libvirt-daemon bridge-utils \
    openjdk11-jdk-headless \
    alsa-lib alsa-utils \
    supervisor tar gzip procps net-tools sudo unzip shadow \
    xvfb x11-xserver-utils x11-utils

# Install Node.js 20
RUN wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . $HOME/.nvm/nvm.sh && \
    nvm install 20 && \
    npm install -g nport@latest

# Install Android SDK (Minimal)
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p ${ANDROID_HOME} && \
    cd /tmp && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip && \
    unzip -q cmdline-tools.zip && \
    mv cmdline-tools ${ANDROID_HOME}/cmdline-tools && \
    rm cmdline-tools.zip

# Accept Licenses and Install Minimal SDK
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "emulator" \
    "system-images;android-34;google_apis;x86_64" > /dev/null 2>&1

# Create AVD
RUN ${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager create avd \
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
    echo "hw.gpu.mode=host" >> /root/.android/avd/cloud_phone.avd/config.ini

# User Setup
RUN adduser -D androidusr && \
    addgroup androidusr sudo && \
    echo "androidusr ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/androidusr/{logs,backup,data} && \
    chown -R androidusr:androidusr /home/androidusr

# ws-scrcpy (Server side)
RUN apk add --no-cache git python3 make g++ build-base linux-headers && \
    git clone --depth 1 https://github.com/NetrisTV/ws-scrcpy.git /opt/ws-scrcpy && \
    cd /opt/ws-scrcpy && \
    . $HOME/.nvm/nvm.sh && \
    npm install && \
    npx tsc -b

# Project Files
COPY scripts/ /usr/local/bin/
COPY config/ /etc/cloud-phone/

RUN chmod +x /usr/local/bin/*.sh && \
    chown -R androidusr:androidusr /usr/local/bin /opt/ws-scrcpy /etc/cloud-phone /opt/android-sdk

EXPOSE 8000 5555

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

CMD ["supervisord", "-c", "/etc/cloud-phone/supervisord.conf", "-n"]
