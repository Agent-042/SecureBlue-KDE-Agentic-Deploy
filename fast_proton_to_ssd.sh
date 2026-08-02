#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="/var/run/proton_ssd_download.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Downloader already running."; exit 0; }

LOCAL_STAGE="/var/tmp/Proton_Drive_Local_Staging"
mkdir -p "$LOCAL_STAGE"

OTP_SECRET="5J4XTLC2YSQG7XFXAX7EMYXPPTOYYN4W"
USERNAME="jack.derleth@protonmail.com"
PASSWORD="Suck-My-Ballz-69-420!!"

refresh_proton_session() {
    python3 -c "
import base64, hmac, hashlib, time, struct, subprocess

secret = '$OTP_SECRET'
key = base64.b32decode(secret, True)
now = int(time.time()) // 30
msg = struct.pack('>Q', now)
h = hmac.new(key, msg, hashlib.sha1).digest()
o = h[19] & 15
code = (struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff) % 1000000
totp = f'{code:06d}'
print(f'[{time.strftime(\"%Y-%m-%dT%H:%M:%S\")}] Refreshing ProtonDrive session with 2FA code {totp}...')

subprocess.run(['rclone', 'config', 'delete', 'protondrive'], capture_output=True)
res = subprocess.run([
    'rclone', 'config', 'create', 'protondrive', 'protondrive',
    'username', '$USERNAME',
    'password', '$PASSWORD',
    '2fa', totp,
    '--non-interactive'
], capture_output=True, text=True)
if res.returncode != 0:
    print('Failed to recreate protondrive config:', res.stderr)
"
}

echo "[$(date -Iseconds)] Starting Resumable Proton -> SSD Downloader Engine..."

while true; do
  refresh_proton_session
  echo "[$(date -Iseconds)] Streaming Proton Drive files to local NVMe SSD..."
  rclone copy protondrive: "$LOCAL_STAGE" \
    --transfers=12 \
    --checkers=12 \
    --tpslimit=3 \
    --tpslimit-burst=3 \
    --buffer-size=64M \
    --use-mmap \
    --protondrive-enable-caching \
    --exclude "Proton Downloads/**" \
    --retries=5 \
    --retries-sleep=30s \
    --low-level-retries=5 \
    --log-file=/var/log/fast_migration_download.log \
    --stats=10s \
    -v || true

  echo "[$(date -Iseconds)] Sync pass completed. Next verification pass in 30s..."
  sleep 30
done


