#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "LAUNCHING UNLEASHED RESUMABLE PROTON -> SSD -> GDRIVE SWARM"
echo "=========================================================="

# Kill any existing older scripts
pkill -f "download_proton_to_ssd" || true
pkill -f "upload_ssd_to_gdrive" || true
pkill -f "run_proton_migration" || true

chmod +x /root/fast_proton_to_ssd.sh /root/fast_ssd_to_gdrive.sh

# Launch Downloader in background
nohup /root/fast_proton_to_ssd.sh > /dev/null 2>&1 &
echo "[+] Resumable High-Speed SSD Downloader launched."

# Launch Uploader in background
nohup /root/fast_ssd_to_gdrive.sh > /dev/null 2>&1 &
echo "[+] Resumable High-Speed Google Drive Uploader launched."

echo "All systems operational."
