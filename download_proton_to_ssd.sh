#!/usr/bin/env bash
set -euo pipefail

# Ensure local SSD staging directory exists
LOCAL_STAGE="/var/tmp/Proton_Drive_Local_Staging"
mkdir -p "$LOCAL_STAGE"

# Generate fresh TOTP
TOTP_CODE=$(python3 -c '
import hmac, hashlib, struct, time, base64

secret = "5J4XTLC2YSQG7XFXAX7EMYXPPTOYYN4W"
key = base64.b32decode(secret, True)
now = int(time.time()) // 30
msg = struct.pack(">Q", now)
h = hmac.new(key, msg, hashlib.sha1).digest()
o = h[19] & 15
h = (struct.unpack(">I", h[o:o+4])[0] & 0x7fffffff) % 1000000
print(f"{h:06d}")
')

# Update protondrive rclone config with fresh 2FA
rclone config create protondrive protondrive username jack.derleth@protonmail.com password "Suck-My-Ballz-69-420!!" 2fa "$TOTP_CODE" --non-interactive >/dev/null 2>&1 || true

echo "Starting secondary parallel download from Proton Drive to local SSD ($LOCAL_STAGE)..."

# Run rclone copy from protondrive to local SSD
exec rclone copy protondrive: "$LOCAL_STAGE" \
  --fast-list \
  --transfers=16 \
  --checkers=16 \
  --buffer-size=64M \
  --use-mmap \
  --protondrive-enable-caching \
  --exclude "Proton Downloads/**" \
  --log-file=/var/log/rclone_proton_ssd_download.log \
  --stats=5s \
  -P \
  --stats-one-line
