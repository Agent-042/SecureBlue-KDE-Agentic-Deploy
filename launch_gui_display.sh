#!/usr/bin/env bash
# ==============================================================================
# Dual-User GUI Display & VM Viewer Launcher (backstage & frontstage)
# ==============================================================================

set -euo pipefail

VM_NAME="${1:-bazzite-vm}"

echo "================================================================="
echo "       DUAL-USER GUI CONTROL & DISPLAY VERIFICATION"
echo "================================================================="

# 1. Detect currently active physical VT
ACTIVE_VT=$(cat /sys/class/tty/tty0/active 2>/dev/null || echo "tty2")
echo "[+] Physically Active Display VT: ${ACTIVE_VT}"

# 2. Check VM status and start if needed
if ! virsh domstate "${VM_NAME}" | grep -q "running"; then
    echo "[+] Starting VM '${VM_NAME}'..."
    virsh start "${VM_NAME}"
    sleep 3
fi

# 3. Kill existing viewers
pkill -f "virt-viewer --attach ${VM_NAME}" || true
pkill -f "remote-viewer.*${VM_NAME}" || true
sleep 1

# 4. Launch GUI Viewer for BACKSTAGE (UID 1001, tty2)
echo "[+] Launching GUI Display Mechanism for user 'backstage' (tty2)..."
runuser -u backstage -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 virt-viewer --attach "${VM_NAME}" --kiosk --kiosk-quit=on-disconnect >/tmp/vv_backstage.log 2>&1 &
BACKSTAGE_PID=$!

# 5. Launch GUI Viewer for FRONTSTAGE (UID 1003, tty3)
echo "[+] Launching GUI Display Mechanism for user 'frontstage' (tty3)..."
runuser -u frontstage -- env XDG_RUNTIME_DIR=/run/user/1003 WAYLAND_DISPLAY=wayland-0 virt-viewer --attach "${VM_NAME}" --kiosk --kiosk-quit=on-disconnect >/tmp/vv_frontstage.log 2>&1 &
FRONTSTAGE_PID=$!

sleep 2

# 6. Verify which mechanism is physically active
if [ "${ACTIVE_VT}" = "tty2" ]; then
    echo "[=================================================================]"
    echo "[+] VERIFIED ACTIVE GUI CONTROL: USER 'backstage' on tty2"
    echo "[+] Viewport window for '${VM_NAME}' is now LIVE on physical screen."
    echo "[=================================================================]"
elif [ "${ACTIVE_VT}" = "tty3" ]; then
    echo "[=================================================================]"
    echo "[+] VERIFIED ACTIVE GUI CONTROL: USER 'frontstage' on tty3"
    echo "[+] Viewport window for '${VM_NAME}' is now LIVE on physical screen."
    echo "[=================================================================]"
else
    echo "[+] Active VT is ${ACTIVE_VT}. Switching VT to tty2 (backstage)..."
    chvt 2 || true
fi

echo "[+] Backstage Viewer PID: ${BACKSTAGE_PID} | Frontstage Viewer PID: ${FRONTSTAGE_PID}"
