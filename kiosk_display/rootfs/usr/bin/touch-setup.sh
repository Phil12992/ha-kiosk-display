#!/usr/bin/env bash
# ============================================================================
# Kiosk Display - Touchscreen Setup
# Detects and configures USB/HDMI touchscreens
# ============================================================================

echo "# Kiosk Display - Touchscreen Configuration"
echo "# Generated: $(date -Iseconds)"

# Source environment for display info
if [ -f /var/run/kiosk/env.sh ]; then
    source /var/run/kiosk/env.sh
fi

# ---- Detect touchscreen devices ----
detect_touch_devices() {
    echo "# --- Touchscreen Detection ---" >&2
    
    TOUCH_DEVICES=()
    
    if [ ! -d /dev/input ]; then
        echo "# WARNING: /dev/input not available" >&2
        return
    fi
    
    # Use libinput to list devices
    if command -v libinput > /dev/null 2>&1; then
        while IFS= read -r line; do
            if echo "${line}" | grep -qi "touch"; then
                DEVICE=$(echo "${line}" | grep -oP '/dev/input/event\d+')
                if [ -n "${DEVICE}" ]; then
                    TOUCH_DEVICES+=("${DEVICE}")
                    echo "# Found touchscreen via libinput: ${DEVICE}" >&2
                fi
            fi
        done < <(libinput list-devices 2>/dev/null)
    fi
    
    # Fallback: check evdev capabilities
    if [ ${#TOUCH_DEVICES[@]} -eq 0 ]; then
        for event_dev in /dev/input/event*; do
            if [ ! -c "${event_dev}" ]; then
                continue
            fi
            
            # Check if device has ABS_MT_POSITION_X (multitouch)
            if command -v evtest > /dev/null 2>&1; then
                if evtest --info "${event_dev}" 2>/dev/null | grep -q "ABS_MT_POSITION_X\|ABS_X"; then
                    TOUCH_DEVICES+=("${event_dev}")
                    DEVICE_NAME=$(cat /sys/class/input/$(basename ${event_dev})/device/name 2>/dev/null || echo "unknown")
                    echo "# Found touch device via evtest: ${event_dev} (${DEVICE_NAME})" >&2
                fi
            fi
        done
    fi
    
    echo "export KIOSK_TOUCH_DEVICE_COUNT=${#TOUCH_DEVICES[@]}"
    
    if [ ${#TOUCH_DEVICES[@]} -gt 0 ]; then
        echo "export KIOSK_TOUCH_DEVICE=\"${TOUCH_DEVICES[0]}\""
        echo "export KIOSK_TOUCH_DEVICES=\"${TOUCH_DEVICES[*]}\""
    fi
}

# ---- Map touch to display ----
map_touch_to_display() {
    MAPPING="${KIOSK_TOUCH_MAPPING:-auto}"
    
    if [ "${MAPPING}" = "auto" ]; then
        echo "# Auto-mapping touch to primary display" >&2
        # In most single-monitor setups, no mapping needed
        # For multi-monitor, we need to map touch input to correct output
        return
    fi
    
    if [ -n "${MAPPING}" ] && [ "${MAPPING}" != "auto" ]; then
        echo "# Custom touch mapping: ${MAPPING}" >&2
        echo "export KIOSK_TOUCH_MAP=\"${MAPPING}\""
    fi
}

# ---- Setup on-screen keyboard ----
setup_keyboard() {
    if [ "${KIOSK_ONSCREEN_KEYBOARD}" = "true" ]; then
        echo "# On-screen keyboard enabled" >&2
        echo "export KIOSK_OSK_ENABLED=true"
        
        if command -v squeekboard > /dev/null 2>&1; then
            echo "export KIOSK_OSK_CMD=squeekboard" 
        else
            echo "# WARNING: No on-screen keyboard binary found" >&2
            echo "export KIOSK_OSK_ENABLED=false"
        fi
    fi
}

# ---- Main ----
detect_touch_devices
map_touch_to_display
setup_keyboard

echo ""
echo "# Touchscreen setup complete"
