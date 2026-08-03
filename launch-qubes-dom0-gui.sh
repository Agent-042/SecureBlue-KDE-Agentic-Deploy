#!/bin/bash
# launch-qubes-dom0-gui.sh
# Launches Qubes OS Dom0 GUI Portal window reliably with automatic reconnection and fallback handling

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1001}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export DISPLAY="${DISPLAY:-:0}"

echo "[*] Checking Qubes Agentic Powerhouse VM status..."
if ! virsh domstate qubes-agentic-powerhouse 2>/dev/null | grep -q "running"; then
    echo " -> Domain is shut off. Starting qubes-agentic-powerhouse..."
    virsh start qubes-agentic-powerhouse 2>&1 || true
    sleep 2
fi

echo "[*] Launching virt-viewer Dom0 GUI Portal..."
exec virt-viewer --connect qemu:///system --attach --reconnect qubes-agentic-powerhouse
