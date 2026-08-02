#!/usr/bin/env bash
set -euo pipefail

LOCAL_STAGE="/var/tmp/Proton_Drive_Local_Staging"
mkdir -p "$LOCAL_STAGE"

echo "Starting local SSD to Google Drive upload ($LOCAL_STAGE -> gdrive:Proton_Drive_Migration)..."

exec rclone copy "$LOCAL_STAGE" gdrive:Proton_Drive_Migration \
  --transfers=16 \
  --checkers=16 \
  --drive-chunk-size=128M \
  --buffer-size=64M \
  --tpslimit=6 \
  --tpslimit-burst=6 \
  --retries=10 \
  --retries-sleep=10s \
  --exclude "*.partial" \
  --exclude "**/*.partial" \
  --update \
  --use-mmap \
  --log-file=/var/log/rclone_ssd_to_gdrive.log \
  --stats=5s \
  -P \
  --stats-one-line
