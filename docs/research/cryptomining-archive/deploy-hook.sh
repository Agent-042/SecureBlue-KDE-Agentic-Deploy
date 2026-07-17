#!/bin/bash
# Helper to install the libvirt QEMU hook.
# Run this interactively; it requires run0 elevation.

set -euo pipefail

SOURCE="${HOME}/qemu-hook-temp"
DEST="/etc/libvirt/hooks/qemu"

echo "Deploying ${SOURCE} -> ${DEST} via run0..."
run0 mkdir -p "$(dirname "$DEST")"
run0 cp "$SOURCE" "$DEST"
run0 chmod +x "$DEST"
echo "Hook deployed to ${DEST}."
echo "Restart libvirtd if it was already running: run0 systemctl restart libvirtd"
