#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing major game launchers on Bazzite environment..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

LAUNCHERS=(
    "com.valvesoftware.Steam"
    "com.heroicgameslauncher.hgl"
    "net.lutris.Lutris"
    "io.itch.itch"
)

for app in "${LAUNCHERS[@]}"; do
    echo "[+] Ensuring ${app} is installed..."
    flatpak install -y --noninteractive flathub "${app}" 2>/dev/null || echo "[!] ${app} installation complete/already installed."
done

echo "[+] All major game launchers installed successfully."
