#!/usr/bin/env bash
# ============================================================================
# Kiosk Display - Chromium Browser Launch Script
# Starts Chromium with optimized kiosk flags
# ============================================================================

# Source environment
if [ -f /var/run/kiosk/env.sh ]; then
    source /var/run/kiosk/env.sh
fi

# ---- Determine Chromium binary ----
CHROMIUM_BIN=""
for bin in chromium chromium-browser google-chrome; do
    if command -v "${bin}" > /dev/null 2>&1; then
        CHROMIUM_BIN="${bin}"
        break
    fi
done

if [ -z "${CHROMIUM_BIN}" ]; then
    echo "FATAL: No Chromium binary found!"
    exit 1
fi

echo "INFO: Using browser: ${CHROMIUM_BIN}"

# ---- Profile cleanup on crash ----
PROFILE_DIR="/data/chromium-profile"
if [ -f "${PROFILE_DIR}/Default/Preferences" ]; then
    # Fix crash recovery flags
    if command -v jq > /dev/null 2>&1; then
        jq '.profile.exit_type = "Normal" | .profile.exited_cleanly = true' \
            "${PROFILE_DIR}/Default/Preferences" > /tmp/prefs_fixed.json 2>/dev/null && \
            mv /tmp/prefs_fixed.json "${PROFILE_DIR}/Default/Preferences"
    else
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "${PROFILE_DIR}/Default/Preferences" 2>/dev/null
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "${PROFILE_DIR}/Default/Preferences" 2>/dev/null
    fi
fi

# Remove SingletonLock to prevent "already running" errors
rm -f "${PROFILE_DIR}/SingletonLock" 2>/dev/null
rm -f "${PROFILE_DIR}/SingletonCookie" 2>/dev/null
rm -f "${PROFILE_DIR}/SingletonSocket" 2>/dev/null

# ---- Build Chromium flags ----
CHROMIUM_FLAGS=(
    # Kiosk mode
    --kiosk
    --start-fullscreen
    --start-maximized
    --no-first-run
    --no-default-browser-check
    
    # Profile
    --user-data-dir="${PROFILE_DIR}"
    
    # Security (required in container)
    --no-sandbox
    --test-type
    
    # UI cleanup
    --disable-infobars
    --disable-translate
    --disable-suggestions-ui
    --disable-save-password-bubble
    --disable-session-crashed-bubble
    --noerrdialogs
    --hide-scrollbars
    --disable-pinch
    
    # Performance
    --disable-background-networking
    --disable-sync
    --disable-default-apps
    --disable-extensions
    --disable-component-update
    --disable-domain-reliability
    --disable-client-side-phishing-detection
    --disable-hang-monitor
    --disable-popup-blocking
    --disable-prompt-on-repost
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
    --disable-ipc-flooding-protection
    
    # Memory optimization
    --disk-cache-size=0
    --media-cache-size=0
    --disable-dev-shm-usage
    --aggressive-cache-discard
    
    # Media
    --autoplay-policy=no-user-gesture-required
    
    # Updates
    --check-for-update-interval=31536000
    --simulate-outdated-no-au="Tue, 31 Dec 2099 23:59:59 GMT"
)

# ---- GPU / Display flags ----
GPU_TYPE="${KIOSK_GPU_TYPE:-unknown}"
echo "INFO: GPU type detected: ${GPU_TYPE}"

# Ozone platform (Wayland or X11)
if [ "${KIOSK_DISPLAY_SERVER}" = "cage" ] || [ "${KIOSK_DISPLAY_SERVER}" = "weston" ]; then
    CHROMIUM_FLAGS+=(
        --enable-features=UseOzonePlatform,Touchscreen,VaapiVideoDecoder,WebRTCPipeWireCapturer
        --ozone-platform=wayland
    )
else
    CHROMIUM_FLAGS+=(
        --enable-features=Touchscreen,VaapiVideoDecoder
    )
fi

# GPU acceleration
CHROMIUM_FLAGS+=(
    --enable-gpu
    --enable-gpu-rasterization
    --enable-zero-copy
    --ignore-gpu-blocklist
    --enable-accelerated-video-decode
    --gpu-sandbox-failures-fatal=no
)

# GPU-specific flags
case "${GPU_TYPE}" in
    vc4|v3d|broadcom)
        echo "INFO: Applying Raspberry Pi GPU optimizations"
        CHROMIUM_FLAGS+=(
            --enable-native-gpu-memory-buffers
            --use-gl=egl
        )
        ;;
    intel)
        echo "INFO: Applying Intel GPU optimizations"
        CHROMIUM_FLAGS+=(
            --enable-native-gpu-memory-buffers
            --use-gl=egl
        )
        ;;
    amd|amdgpu)
        echo "INFO: Applying AMD GPU optimizations"
        CHROMIUM_FLAGS+=(
            --use-gl=egl
        )
        ;;
esac

# ---- Zoom ----
ZOOM="${KIOSK_ZOOM:-100}"
if [ "${ZOOM}" != "100" ]; then
    SCALE=$(echo "scale=2; ${ZOOM} / 100" | bc 2>/dev/null || echo "1.0")
    CHROMIUM_FLAGS+=(--force-device-scale-factor="${SCALE}")
    echo "INFO: Zoom set to ${ZOOM}% (scale factor: ${SCALE})"
fi

# ---- Dark mode ----
if [ "${KIOSK_DARK_MODE}" = "true" ]; then
    CHROMIUM_FLAGS+=(--force-dark-mode)
fi

# ---- Touch support ----
if [ "${KIOSK_TOUCH_ENABLED}" = "true" ]; then
    CHROMIUM_FLAGS+=(--touch-events=enabled)
fi

# ---- Custom browser flags ----
if [ -n "${KIOSK_BROWSER_FLAGS}" ]; then
    echo "INFO: Adding custom browser flags: ${KIOSK_BROWSER_FLAGS}"
    # shellcheck disable=SC2206
    CHROMIUM_FLAGS+=(${KIOSK_BROWSER_FLAGS})
fi

# ---- Determine URL ----
URL="${KIOSK_URL:-http://supervisor/core}"

# If token is provided, use auto-login page first
if [ -n "${KIOSK_TOKEN}" ]; then
    echo "INFO: Using Long-Lived Access Token for authentication"
    # Encode parameters for the login helper page
    URL="file:///usr/share/kiosk/login.html?url=$(echo -n "${URL}" | jq -sRr @uri)&token=$(echo -n "${KIOSK_TOKEN}" | jq -sRr @uri)"
elif [ -n "${KIOSK_USERNAME}" ] && [ -n "${KIOSK_PASSWORD}" ]; then
    echo "INFO: Using username/password for authentication"
    URL="file:///usr/share/kiosk/login.html?url=$(echo -n "${URL}" | jq -sRr @uri)&username=$(echo -n "${KIOSK_USERNAME}" | jq -sRr @uri)&password=$(echo -n "${KIOSK_PASSWORD}" | jq -sRr @uri)"
fi

echo "INFO: Starting Chromium kiosk at: ${KIOSK_URL}"
echo "INFO: Total flags: ${#CHROMIUM_FLAGS[@]}"

# ---- Launch ----
exec "${CHROMIUM_BIN}" "${CHROMIUM_FLAGS[@]}" "${URL}"
