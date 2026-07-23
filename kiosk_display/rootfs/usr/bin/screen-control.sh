#!/usr/bin/env bash
# ============================================================================
# Kiosk Display - Screen Control
# Controls screen power, brightness, and browser actions
# Usage: screen-control.sh [on|off|toggle|status|reload|screenshot|brightness]
# ============================================================================

# Source environment
if [ -f /var/run/kiosk/env.sh ]; then
    source /var/run/kiosk/env.sh
fi

export XDG_RUNTIME_DIR=/run/user/0

ACTION="${1:-status}"

# ---- Screen Power Control ----
screen_on() {
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            # Try wlopm first (Wayland)
            if command -v wlopm > /dev/null 2>&1; then
                wlopm --on '*' 2>/dev/null && return 0
            fi
            # Fallback: write to DRM directly
            for bl in /sys/class/backlight/*/bl_power; do
                echo 0 > "${bl}" 2>/dev/null
            done
            ;;
        xorg)
            export DISPLAY=:0
            xset dpms force on 2>/dev/null
            xset s reset 2>/dev/null
            ;;
    esac
    echo '{"status": "on"}'
}

screen_off() {
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            if command -v wlopm > /dev/null 2>&1; then
                wlopm --off '*' 2>/dev/null && return 0
            fi
            for bl in /sys/class/backlight/*/bl_power; do
                echo 1 > "${bl}" 2>/dev/null
            done
            ;;
        xorg)
            export DISPLAY=:0
            xset dpms force off 2>/dev/null
            ;;
    esac
    echo '{"status": "off"}'
}

screen_toggle() {
    # Check current state
    CURRENT=$(screen_status_raw)
    if [ "${CURRENT}" = "on" ]; then
        screen_off
    else
        screen_on
    fi
}

screen_status_raw() {
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            if command -v wlopm > /dev/null 2>&1; then
                STATE=$(wlopm 2>/dev/null | head -1 | awk '{print $2}')
                if [ "${STATE}" = "on" ]; then
                    echo "on"
                else
                    echo "off"
                fi
            else
                echo "unknown"
            fi
            ;;
        xorg)
            export DISPLAY=:0
            if xset q 2>/dev/null | grep -q "Monitor is On"; then
                echo "on"
            else
                echo "off"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

screen_status() {
    STATE=$(screen_status_raw)
    echo "{\"status\": \"${STATE}\"}"
}

# ---- Browser Reload ----
browser_reload() {
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            # Use wtype to send F5 (Wayland)
            if command -v wtype > /dev/null 2>&1; then
                export WAYLAND_DISPLAY=wayland-0
                wtype -k F5 2>/dev/null
            fi
            ;;
        xorg)
            export DISPLAY=:0
            xdotool key F5 2>/dev/null
            ;;
    esac
    echo '{"action": "reload", "status": "ok"}'
}

# ---- Screenshot ----
take_screenshot() {
    OUTPUT_FILE="${2:-/tmp/kiosk-screenshot.png}"
    
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            if command -v grim > /dev/null 2>&1; then
                export WAYLAND_DISPLAY=wayland-0
                grim "${OUTPUT_FILE}" 2>/dev/null
            fi
            ;;
        xorg)
            export DISPLAY=:0
            if command -v scrot > /dev/null 2>&1; then
                scrot "${OUTPUT_FILE}" 2>/dev/null
            fi
            ;;
    esac
    
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "{\"status\": \"ok\", \"file\": \"${OUTPUT_FILE}\"}"
    else
        echo '{"status": "error", "message": "Screenshot failed"}'
    fi
}

# ---- Brightness ----
set_brightness() {
    LEVEL="${2:-100}"
    
    for bl_dir in /sys/class/backlight/*/; do
        if [ -d "${bl_dir}" ]; then
            MAX=$(cat "${bl_dir}/max_brightness" 2>/dev/null || echo 255)
            VALUE=$((MAX * LEVEL / 100))
            echo "${VALUE}" > "${bl_dir}/brightness" 2>/dev/null
        fi
    done
    
    echo "{\"brightness\": ${LEVEL}}"
}

# ---- Input simulation ----
send_key() {
    KEY="${2}"
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            if command -v wtype > /dev/null 2>&1; then
                export WAYLAND_DISPLAY=wayland-0
                wtype -k "${KEY}" 2>/dev/null
            fi
            ;;
        xorg)
            export DISPLAY=:0
            xdotool key "${KEY}" 2>/dev/null
            ;;
    esac
    echo "{\"key\": \"${KEY}\", \"status\": \"ok\"}"
}

move_mouse() {
    X="${2:-0}"
    Y="${3:-0}"
    case "${KIOSK_DISPLAY_SERVER}" in
        xorg)
            export DISPLAY=:0
            xdotool mousemove "${X}" "${Y}" 2>/dev/null
            ;;
    esac
    echo "{\"x\": ${X}, \"y\": ${Y}, \"status\": \"ok\"}"
}

send_text() {
    TEXT="${2}"
    case "${KIOSK_DISPLAY_SERVER}" in
        cage|weston)
            if command -v wtype > /dev/null 2>&1; then
                export WAYLAND_DISPLAY=wayland-0
                wtype "${TEXT}" 2>/dev/null
            fi
            ;;
        xorg)
            export DISPLAY=:0
            xdotool type -- "${TEXT}" 2>/dev/null
            ;;
    esac
    echo "{\"text\": \"${TEXT}\", \"status\": \"ok\"}"
}

# ---- Main dispatch ----
case "${ACTION}" in
    on)          screen_on ;;
    off)         screen_off ;;
    toggle)      screen_toggle ;;
    status)      screen_status ;;
    reload)      browser_reload ;;
    screenshot)  take_screenshot "$@" ;;
    brightness)  set_brightness "$@" ;;
    key)         send_key "$@" ;;
    mouse)       move_mouse "$@" ;;
    text)        send_text "$@" ;;
    *)
        echo "Usage: $0 {on|off|toggle|status|reload|screenshot|brightness|key|mouse|text}"
        exit 1
        ;;
esac
