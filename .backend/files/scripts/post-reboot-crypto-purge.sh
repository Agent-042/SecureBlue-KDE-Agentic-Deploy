#!/usr/bin/env bash
# Post-Reboot Crypto Purge Enforcement Script
set -euo pipefail

echo "=================================================="
echo "[PURGE] Executing Post-Reboot Crypto-Purge Check..."
echo "=================================================="

# 1. Stop and disable folding.service if present
if systemctl is-active --quiet folding.service 2>/dev/null; then
    echo "[!] Stopping folding.service..."
    systemctl stop folding.service || true
    systemctl disable folding.service || true
fi

# 2. Remove folding podman volume and CUDA/miner container images
echo "[*] Cleaning up Podman miner images and volumes..."
podman volume rm -f folding-data 2>/dev/null || true
podman rmi -f docker.io/nvidia/cuda:12.5.1-base-ubuntu24.04 2>/dev/null || true
podman rmi -f docker.io/library/ubuntu:24.04 2>/dev/null || true

# 3. Clean local user miner paths
echo "[*] Purging residual miner directory paths..."
rm -rf ~/.alephium ~/.alephium-wallets ~/.shared-ringdb ~/gpu_watchdog.log ~/gpu_watchdog.sh.bak.* 2>/dev/null || true
rm -rf /home/*/.alephium /home/*/.alephium-wallets /home/*/.shared-ringdb 2>/dev/null || true

# 4. Clean CDI GPU passthrough config if present
if [ -f /etc/cdi/nvidia.yaml ]; then
    echo "[*] Removing /etc/cdi/nvidia.yaml..."
    rm -f /etc/cdi/nvidia.yaml
fi

echo "=================================================="
echo "[SUCCESS] Post-Reboot Crypto Purge complete. System is clean."
echo "=================================================="
