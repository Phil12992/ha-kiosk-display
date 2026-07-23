#!/usr/bin/env bash
set -e

# ============================================================================
# Kiosk Display - Initialization Script
# Called by s6 init-config oneshot service
# ============================================================================

# Create runtime directories
mkdir -p /var/run/kiosk
mkdir -p /data/chromium-profile
mkdir -p /var/log/kiosk

# Initialize environment file
ENV_FILE="/var/run/kiosk/env.sh"
echo "# Kiosk Display Environment" > "${ENV_FILE}"
echo "# Generated at $(date -Iseconds)" >> "${ENV_FILE}"

# ---- Read configuration ----
if [ -f /data/options.json ]; then
    HA_URL=$(jq -r '.ha_url // empty' /data/options.json)
    DASHBOARD=$(jq -r '.dashboard // empty' /data/options.json)
    USERNAME=$(jq -r '.username // empty' /data/options.json)
    PASSWORD=$(jq -r '.password // empty' /data/options.json)
    TOKEN=$(jq -r '.token // empty' /data/options.json)
    ZOOM=$(jq -r '.zoom // 100' /data/options.json)
    DARK_MODE=$(jq -r '.dark_mode // true' /data/options.json)
    REFRESH_INTERVAL=$(jq -r '.refresh_interval // 0' /data/options.json)
    SCREEN_TIMEOUT=$(jq -r '.screen_timeout // 0' /data/options.json)
    ROTATE_DISPLAY=$(jq -r '.rotate_display // "normal"' /data/options.json)
    OUTPUT_NUMBER=$(jq -r '.output_number // 0' /data/options.json)
    AUDIO_SINK=$(jq -r '.audio_sink // "auto"' /data/options.json)
    CURSOR_TIMEOUT=$(jq -r '.cursor_timeout // 5' /data/options.json)
    TOUCH_ENABLED=$(jq -r '.touch_enabled // true' /data/options.json)
    TOUCH_MAPPING=$(jq -r '.touch_mapping // "auto"' /data/options.json)
    ONSCREEN_KEYBOARD=$(jq -r '.onscreen_keyboard // false' /data/options.json)
    DISPLAY_SERVER=$(jq -r '.display_server // "auto"' /data/options.json)
    BROWSER_FLAGS=$(jq -r '.browser_flags // empty' /data/options.json)
else
    echo "ERROR: /data/options.json not found!"
    exit 1
fi

# Determine HA URL - use supervisor internal URL if not specified
if [ -z "${HA_URL}" ]; then
    HA_URL="http://supervisor/core"
    echo "INFO: No ha_url configured, using internal supervisor URL"
fi

# Build the full URL with dashboard
KIOSK_URL="${HA_URL}"
if [ -n "${DASHBOARD}" ]; then
    # Remove leading slash if present
    DASHBOARD=$(echo "${DASHBOARD}" | sed 's|^/||')
    KIOSK_URL="${HA_URL}/${DASHBOARD}"
fi

# Append kiosk mode parameter
if echo "${KIOSK_URL}" | grep -q '?'; then
    KIOSK_URL="${KIOSK_URL}&kiosk"
else
    KIOSK_URL="${KIOSK_URL}?kiosk"
fi

# Save all configuration to environment file
cat >> "${ENV_FILE}" << EOF
export KIOSK_URL="${KIOSK_URL}"
export KIOSK_HA_URL="${HA_URL}"
export KIOSK_DASHBOARD="${DASHBOARD}"
export KIOSK_USERNAME="${USERNAME}"
export KIOSK_PASSWORD="${PASSWORD}"
export KIOSK_TOKEN="${TOKEN}"
export KIOSK_ZOOM="${ZOOM}"
export KIOSK_DARK_MODE="${DARK_MODE}"
export KIOSK_REFRESH_INTERVAL="${REFRESH_INTERVAL}"
export KIOSK_SCREEN_TIMEOUT="${SCREEN_TIMEOUT}"
export KIOSK_ROTATE_DISPLAY="${ROTATE_DISPLAY}"
export KIOSK_OUTPUT_NUMBER="${OUTPUT_NUMBER}"
export KIOSK_AUDIO_SINK="${AUDIO_SINK}"
export KIOSK_CURSOR_TIMEOUT="${CURSOR_TIMEOUT}"
export KIOSK_TOUCH_ENABLED="${TOUCH_ENABLED}"
export KIOSK_TOUCH_MAPPING="${TOUCH_MAPPING}"
export KIOSK_ONSCREEN_KEYBOARD="${ONSCREEN_KEYBOARD}"
export KIOSK_DISPLAY_SERVER="${DISPLAY_SERVER}"
export KIOSK_BROWSER_FLAGS="${BROWSER_FLAGS}"
EOF

echo "INFO: Configuration loaded successfully"

# ---- Run hardware detection ----
echo "INFO: Detecting display hardware..."
/usr/bin/display-detect.sh >> "${ENV_FILE}" 2>/var/log/kiosk/display-detect.log

# ---- Setup touchscreen ----
if [ "${TOUCH_ENABLED}" = "true" ]; then
    echo "INFO: Setting up touchscreen..."
    /usr/bin/touch-setup.sh >> "${ENV_FILE}" 2>/var/log/kiosk/touch-setup.log
fi

# ---- Configure audio ----
if [ "${AUDIO_SINK}" != "auto" ] && [ -n "${AUDIO_SINK}" ]; then
    echo "INFO: Configuring audio sink: ${AUDIO_SINK}"
    if command -v pactl > /dev/null 2>&1; then
        pactl set-default-sink "${AUDIO_SINK}" 2>/dev/null || true
    fi
fi

echo "INFO: Kiosk initialization complete"
