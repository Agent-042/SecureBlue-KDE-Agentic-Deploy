#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: /root/run_proton_migration.sh
# DESCRIPTION: High-speed, fault-tolerant Proton Drive to Google Drive migration.
#              Automatically generates live TOTP 2FA and launches multi-threaded sync.
# ==============================================================================

set -o pipefail

OTP_SECRET="5J4XTLC2YSQG7XFXAX7EMYXPPTOYYN4W"
USERNAME="jack.derleth@protonmail.com"
PASSWORD="Suck-My-Ballz-69-420!!"
DEST_FOLDER="gdrive:Proton_Drive_Migration"
LOG_FILE="/var/log/rclone_proton_migration.log"
LOCK_FILE="/var/run/proton_migration.lock"

# Ensure single instance lock
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[$(date -Iseconds)] Migration is already running."
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

# Function to generate live TOTP code using Python standard library
get_totp() {
    python3 -c "
import base64, hmac, hashlib, time, struct
secret = '$1'
key = base64.b32decode(secret, True)
now = int(time.time()) // 30
msg = struct.pack('>Q', now)
h = hmac.new(key, msg, hashlib.sha1).digest()
offset = h[-1] & 0x0f
code = (struct.unpack('>I', h[offset:offset+4])[0] & 0x7fffffff) % 1000000
print(f'{code:06d}')
"
}

update_proton_config() {
    TOTP=$(get_totp "$OTP_SECRET")
    echo "[$(date -Iseconds)] Generating live Proton 2FA TOTP: ${TOTP}"
    rclone config create protondrive protondrive \
        username "${USERNAME}" \
        password "${PASSWORD}" \
        2fa "${TOTP}" \
        --non-interactive >/dev/null 2>&1
}

# Refresh config before starting
update_proton_config

echo "=============================================================================="
echo "          PROTON DRIVE -> GOOGLE DRIVE 700GB MIGRATION SWARM"
echo "=============================================================================="
echo "Source: protondrive:"
echo "Destination: ${DEST_FOLDER}"
echo "Log File: ${LOG_FILE}"
echo "=============================================================================="

ATTEMPT=1
until {
    update_proton_config
    rclone copy protondrive: "${DEST_FOLDER}" \
        --fast-list \
        --transfers=16 \
        --checkers=16 \
        --drive-chunk-size=128M \
        --buffer-size=64M \
        --protondrive-enable-caching \
        --exclude "Proton Downloads/**" \
        --tpslimit=4 \
        --tpslimit-burst=4 \
        --retries=10 \
        --retries-sleep=10s \
        --low-level-retries=10 \
        --track-renames \
        --update \
        --use-mmap \
        --stats=5s \
        -P 2>&1 | tee -a "${LOG_FILE}"
}; do
    echo "[$(date -Iseconds)] Sync attempt #${ATTEMPT} failed. Retrying in 30 seconds..."
    sleep 30
    ATTEMPT=$((ATTEMPT + 1))
done

echo "=============================================================================="
echo "[$(date -Iseconds)] SUCCESS: Proton Drive migration complete!"
echo "=============================================================================="
