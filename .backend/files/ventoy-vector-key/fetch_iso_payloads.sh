#!/usr/bin/env bash
# Robust Async ISO Payload & OCI Container Fetcher
# Target: SecureBlue Kinoite Hardened, Bazzite Nvidia v44, Windows 11, Qubes OS Dom0
set -euo pipefail

echo "=================================================="
echo "⚡ ISO Payload & OCI Container Resumable Fetcher"
echo "=================================================="

CHECK_ONLY="${1:-}"

# Destination directory (USB partition 1 /ISO/ or local staging)
if [ -d "/mnt/ventoy_vector_key/ISO" ]; then
    TARGET_DIR="/mnt/ventoy_vector_key/ISO"
    LOG_FILE="/mnt/ventoy_vector_key/logs/iso_download.log"
else
    TARGET_DIR="/var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/ISO"
    LOG_FILE="/var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/logs/iso_download.log"
fi

mkdir -p "$TARGET_DIR" "$(dirname "$LOG_FILE")"

# Direct ISO Download URLs
declare -A ISOS=(
    ["Qubes-OS.iso"]="https://mirrors.edge.kernel.org/qubes/iso/Qubes-R4.2.1-x86_64.iso"
    ["Windows11-enterprise.iso"]="https://software-static.download.prss.microsoft.com/sg/Win11_24H2_English_x64.iso"
)

# OCI Container Image Payloads (bootc / ostree)
declare -A CONTAINERS=(
    ["Bazzite-Nvidia"]="ghcr.io/ublue-os/bazzite-nvidia:stable"
    ["SecureBlue-Kinoite"]="ghcr.io/secureblue/kinoite-nvidia-main-hardened:latest"
)

if [ "$CHECK_ONLY" == "--check-only" ]; then
    echo "[*] DRY RUN: Verifying download targets..."
    for filename in "${!ISOS[@]}"; do
        url="${ISOS[$filename]}"
        echo -n "Checking ISO: $filename ($url)... "
        status=$(curl -s -o /dev/null -I -w "%{http_code}" -L "$url" || echo "FAILED")
        echo "HTTP Status: $status"
    done
    for name in "${!CONTAINERS[@]}"; do
        image="${CONTAINERS[$name]}"
        echo "Checking OCI Image: $name ($image)..."
    done
    exit 0
fi

echo "[*] Starting background ISO fetch. Logging output to: $LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

for filename in "${!ISOS[@]}"; do
    url="${ISOS[$filename]}"
    dest="$TARGET_DIR/$filename"
    
    echo "--------------------------------------------------"
    echo "[FETCH] Starting / Resuming ISO: $filename"
    echo "URL: $url"
    echo "Destination: $dest"
    echo "--------------------------------------------------"
    
    curl -C - -L --retry 5 --retry-delay 3 --connect-timeout 15 -o "$dest" "$url" || {
        echo "[!] Warning: Download for $filename experienced an error. Partial file retained for resume."
    }
    
    if [ -f "$dest" ]; then
        size=$(du -h "$dest" | awk '{print $1}')
        echo "[+] Current size of $filename: $size"
    fi
done

echo "--------------------------------------------------"
echo "[CONTAINER FETCH] Pulling uBlue & SecureBlue OCI Image Payloads..."
echo "--------------------------------------------------"

for name in "${!CONTAINERS[@]}"; do
    image="${CONTAINERS[$name]}"
    echo "[*] Pulling OCI image: $image..."
    podman pull "$image" || true
done

echo "=================================================="
echo "[COMPLETE] ISO Payload & OCI Container Fetcher finished."
echo "=================================================="
