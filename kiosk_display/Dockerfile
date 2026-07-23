ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    cage \
    weston \
    xserver-xorg-core \
    openbox \
    libgl1-mesa-dri \
    mesa-utils \
    mesa-vulkan-drivers \
    libinput-tools \
    evtest \
    xdotool \
    xinput \
    python3 \
    python3-aiohttp \
    python3-pip \
    alsa-utils \
    pulseaudio-utils \
    unclutter-xfixes \
    scrot \
    grim \
    slurp \
    wlr-randr \
    wtype \
    jq \
    curl \
    procps \
    udev \
    dbus \
    libdrm2 \
    libgbm1 \
    libegl1 \
    libgles2 \
    fonts-liberation \
    fonts-noto \
    bash \
    coreutils \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends wlopm squeekboard || true \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /

RUN dos2unix /usr/bin/*.sh /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/up /etc/s6-overlay/s6-rc.d/*/finish || true \
    && chmod a+x /usr/bin/*.sh /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/up /etc/s6-overlay/s6-rc.d/*/finish || true

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}"
