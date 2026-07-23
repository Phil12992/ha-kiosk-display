#!/usr/bin/env bash
# ============================================================================
# Kiosk Display - Display Hardware Detection
# Detects GPU type, available monitors, and recommended settings
# ============================================================================

# ---- GPU Detection ----
GPU_TYPE="unknown"
GPU_DRIVER="unknown"

detect_gpu() {
    # Check /dev/dri
    if [ ! -d /dev/dri ]; then
        echo "# WARNING: /dev/dri not found - no GPU access" >&2
        echo "export KIOSK_GPU_TYPE=none"
        echo "export KIOSK_GPU_DRIVER=none"
        return
    fi

    # Read DRM driver info
    for card in /dev/dri/card*; do
        CARD_NAME=$(basename "${card}")
        DRIVER_PATH="/sys/class/drm/${CARD_NAME}/device/driver"
        
        if [ -L "${DRIVER_PATH}" ]; then
            DRIVER=$(basename "$(readlink -f "${DRIVER_PATH}")")
            echo "# Detected DRM driver: ${DRIVER} on ${CARD_NAME}" >&2
            
            case "${DRIVER}" in
                vc4*|v3d*)
                    GPU_TYPE="v3d"
                    GPU_DRIVER="${DRIVER}"
                    echo "# Raspberry Pi GPU (VC4/V3D) detected" >&2
                    ;;
                i915|xe)
                    GPU_TYPE="intel"
                    GPU_DRIVER="${DRIVER}"
                    echo "# Intel GPU detected" >&2
                    ;;
                amdgpu|radeon)
                    GPU_TYPE="amd"
                    GPU_DRIVER="${DRIVER}"
                    echo "# AMD GPU detected" >&2
                    ;;
                virtio*|vmwgfx|qxl|bochs*)
                    GPU_TYPE="virtual"
                    GPU_DRIVER="${DRIVER}"
                    echo "# Virtual GPU detected" >&2
                    ;;
                *)
                    GPU_TYPE="generic"
                    GPU_DRIVER="${DRIVER}"
                    echo "# Generic GPU driver: ${DRIVER}" >&2
                    ;;
            esac
            break
        fi
    done

    echo "export KIOSK_GPU_TYPE=${GPU_TYPE}"
    echo "export KIOSK_GPU_DRIVER=${GPU_DRIVER}"
}

# ---- Monitor Detection ----
detect_monitors() {
    echo "# --- Monitor Detection ---" >&2
    
    MONITOR_COUNT=0
    PRIMARY_OUTPUT=""
    
    for connector_dir in /sys/class/drm/card*-*/; do
        if [ ! -d "${connector_dir}" ]; then
            continue
        fi
        
        CONNECTOR=$(basename "${connector_dir}")
        STATUS_FILE="${connector_dir}/status"
        
        if [ ! -f "${STATUS_FILE}" ]; then
            continue
        fi
        
        STATUS=$(cat "${STATUS_FILE}" 2>/dev/null)
        
        # Parse connector type and number
        # Format: card0-HDMI-A-1, card0-DSI-1, card0-DP-1
        CONN_TYPE=$(echo "${CONNECTOR}" | sed 's/card[0-9]*-//' | sed 's/-[0-9]*$//')
        CONN_NUM=$(echo "${CONNECTOR}" | grep -oP '\d+$')
        
        # Get resolution if connected
        RESOLUTION="unknown"
        if [ -f "${connector_dir}/modes" ]; then
            RESOLUTION=$(head -1 "${connector_dir}/modes" 2>/dev/null || echo "unknown")
        fi
        
        echo "# Monitor: ${CONNECTOR} - Status: ${STATUS} - Mode: ${RESOLUTION}" >&2
        
        if [ "${STATUS}" = "connected" ]; then
            MONITOR_COUNT=$((MONITOR_COUNT + 1))
            if [ -z "${PRIMARY_OUTPUT}" ]; then
                PRIMARY_OUTPUT="${CONNECTOR}"
            fi
        fi
    done
    
    echo "export KIOSK_MONITOR_COUNT=${MONITOR_COUNT}"
    echo "export KIOSK_PRIMARY_OUTPUT=\"${PRIMARY_OUTPUT}\""
    
    if [ ${MONITOR_COUNT} -eq 0 ]; then
        echo "# WARNING: No connected monitors detected!" >&2
    else
        echo "# Found ${MONITOR_COUNT} connected monitor(s)" >&2
    fi
}

# ---- DRM Capabilities ----
detect_drm_capabilities() {
    echo "# --- DRM Capabilities ---" >&2
    
    HAS_DRI=false
    HAS_RENDER=false
    
    [ -e /dev/dri/card0 ] && HAS_DRI=true
    [ -e /dev/dri/renderD128 ] && HAS_RENDER=true
    
    echo "export KIOSK_HAS_DRI=${HAS_DRI}"
    echo "export KIOSK_HAS_RENDER=${HAS_RENDER}"
    
    # Check EGL support
    if command -v eglinfo > /dev/null 2>&1; then
        if eglinfo 2>/dev/null | grep -qi "EGL_MESA_platform_surfaceless"; then
            echo "export KIOSK_HAS_EGL=true"
            echo "# EGL surfaceless platform supported" >&2
        fi
    fi
    
    # Check for framebuffer
    if [ -e /dev/fb0 ]; then
        echo "export KIOSK_HAS_FB=true"
        echo "# Framebuffer /dev/fb0 available" >&2
    fi
}

# ---- Xorg config generation (called with --xorg-config flag) ----
if [ "$1" = "--xorg-config" ]; then
    # Generate minimal xorg.conf
    cat << 'XORGCONF'
Section "ServerLayout"
    Identifier     "Layout0"
    Screen         "Screen0"
    InputDevice    "Keyboard0" "CoreKeyboard"
    InputDevice    "Mouse0" "CorePointer"
EndSection

Section "InputDevice"
    Identifier     "Keyboard0"
    Driver         "libinput"
    Option         "XkbLayout" "us"
EndSection

Section "InputDevice"
    Identifier     "Mouse0"
    Driver         "libinput"
EndSection

Section "Device"
    Identifier     "Device0"
    Driver         "modesetting"
    Option         "AccelMethod" "glamor"
    Option         "DRI" "3"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Device         "Device0"
    DefaultDepth   24
EndSection

Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "AllowMouseOpenFail" "true"
    Option "PciForceNone" "true"
    Option "AutoEnableDevices" "true"
    Option "AutoAddDevices" "true"
EndSection
XORGCONF
    exit 0
fi

# ---- Main execution ----
echo "# Kiosk Display - Hardware Detection Report"
echo "# Generated: $(date -Iseconds)"
echo ""

detect_gpu
detect_monitors
detect_drm_capabilities

echo ""
echo "# Detection complete"
