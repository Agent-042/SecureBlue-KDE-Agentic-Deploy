#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="/var/run/ssd_to_gdrive.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Uploader already running."; exit 0; }

LOCAL_STAGE="/var/tmp/Proton_Drive_Local_Staging"
mkdir -p "$LOCAL_STAGE"

echo "[$(date -Iseconds)] Starting Max-Speed Resumable SSD -> Google Drive Uploader..."

while true; do
  # Bolt ⚡: Added --fast-list to prevent N+1 query API bottlenecks and batch directory listings
  rclone copy "$LOCAL_STAGE" gdrive:Proton_Drive_Migration \
    --fast-list \
    --transfers=16 \
    --checkers=16 \
    --drive-chunk-size=256M \
    --buffer-size=128M \
    --tpslimit=10 \
    --tpslimit-burst=10 \
    --retries=20 \
    --retries-sleep=5s \
    --exclude '*.partial' \
    --exclude '**/*.partial' \
    --update \
    --use-mmap \
    --log-file=/var/log/fast_migration_upload.log \
    --stats=10s \
    -v || true

  sleep 5
done
