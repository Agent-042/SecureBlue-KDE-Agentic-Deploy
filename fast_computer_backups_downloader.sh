#!/usr/bin/env bash
# Master Fast Parallel Computer Backups Downloader Engine
set -euo pipefail

LOCKFILE="/var/run/fast_computer_backups_downloader.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Computer Backups Downloader already running."; exit 0; }

mkdir -p /var/tmp/Proton_Drive_Local_Staging/Computer_Backup_1
mkdir -p /var/tmp/Proton_Drive_Local_Staging/Computer_Backup_2

LOG1="/var/log/fast_computer1_download.log"
LOG2="/var/log/fast_computer2_download.log"

echo "[$(date -Iseconds)] Starting Parallel Extraction for Computer Backup 1 & 2..."

# Launch Computer Backup 1 downloader
/root/rclone-custom copy proton_computer1: /var/tmp/Proton_Drive_Local_Staging/Computer_Backup_1 \
    --transfers=16 \
    --checkers=16 \
    --tpslimit=12 \
    --tpslimit-burst=12 \
    --buffer-size=128M \
    --use-mmap \
    --protondrive-enable-caching \
    --retries=20 \
    --retries-sleep=5s \
    --low-level-retries=20 \
    --log-file="$LOG1" \
    --stats=5s \
    -P \
    --stats-one-line &
PID1=$!

# Launch Computer Backup 2 downloader
/root/rclone-custom copy proton_computer2: /var/tmp/Proton_Drive_Local_Staging/Computer_Backup_2 \
    --transfers=16 \
    --checkers=16 \
    --tpslimit=12 \
    --tpslimit-burst=12 \
    --buffer-size=128M \
    --use-mmap \
    --protondrive-enable-caching \
    --retries=20 \
    --retries-sleep=5s \
    --low-level-retries=20 \
    --log-file="$LOG2" \
    --stats=5s \
    -P \
    --stats-one-line &
PID2=$!

echo "[$(date -Iseconds)] Worker 1 PID: $PID1 | Worker 2 PID: $PID2"
wait $PID1 $PID2
echo "[$(date -Iseconds)] Both Computer Backup Share Extractions Completed!"
