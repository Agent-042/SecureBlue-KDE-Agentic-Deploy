#!/bin/bash
# Launch Ptyxis (Bluefin Terminal) in human GUI session with Agentic Powerhouse profile

export XDG_RUNTIME_DIR="/run/user/1001"
export WAYLAND_DISPLAY="wayland-0"
export DISPLAY=":0"

echo "[*] Launching Bluefin Ptyxis Terminal in Human GUI..."
runuser -u backstage -- env XDG_RUNTIME_DIR="/run/user/1001" WAYLAND_DISPLAY="wayland-0" DISPLAY=":0" ptyxis &
echo "[+] Ptyxis Terminal launched successfully."
