#!/bin/bash
# Single-step Qubes OS Launcher Script
set -e

VM_NAME="qubes-agentic-powerhouse"
USER_NAME="backstage"
USER_UID=1001
RUNTIME_DIR="/run/user/${USER_UID}"
WAYLAND_DISP="wayland-0"

# 1. Ensure libvirt/virtqemud services are active
if ! systemctl is-active --quiet virtqemud && ! systemctl is-active --quiet libvirtd; then
    systemctl start virtqemud.socket virtqemud libvirtd || true
fi

# 2. Check if VM is running, start if shut off
VM_STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || echo "shut off")
if [[ "$VM_STATE" != "running" ]]; then
    echo "Starting VM $VM_NAME..."
    virsh -c qemu:///system start "$VM_NAME"
    sleep 2
fi

# 3. Present GUI viewer on user's Wayland desktop session
echo "Presenting $VM_NAME GUI to user $USER_NAME..."
runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR="$RUNTIME_DIR" WAYLAND_DISPLAY="$WAYLAND_DISP" virt-viewer -c qemu:///system "$VM_NAME" &

echo "SUCCESS: $VM_NAME launched and presented."
