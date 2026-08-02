#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: /root/migration_swarm.sh
# ROLE: Root System Architect & Swarm Migration Lead
# DESCRIPTION: Bulletproof, fault-tolerant, resumable migration state machine
#               transferring 700GB from Proton Drive to Google Drive via native rclone.
# ==============================================================================

set -o pipefail

# Configuration Variables
SRC_REMOTE="proton_remote:"
DST_REMOTE="gdrive_remote:"
LOG_FILE="/var/log/rclone_migration.log"
LOCK_FILE="/var/run/migration_swarm.lock"
COOLDOWN_SECONDS=60

# Prevent concurrent execution instances
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[$(date -Iseconds)] ERROR: Another migration instance is already running." >&2
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

echo "=============================================================================="
echo "          PROTON DRIVE -> GOOGLE DRIVE 700GB SWARM MIGRATION"
echo "=============================================================================="
echo "Host OS: SecureBlue KDE (Fedora Atomic)"
echo "Hardware Profile: Intel Core Ultra 9 | 32GB RAM | 300 Gbps Network Pipe"
echo "Source: ${SRC_REMOTE}"
echo "Destination: ${DST_REMOTE}"
echo "Log File: ${LOG_FILE}"
echo "=============================================================================="

# Interruption trap handler for graceful shutdown
cleanup() {
    echo ""
    echo "[$(date -Iseconds)] WARNING: Interruption signal received (SIGINT/SIGTERM)."
    echo "[$(date -Iseconds)] Flushing buffers and terminating rclone safely..."
    pkill -P $$ rclone 2>/dev/null || true
    rm -f "$LOCK_FILE"
    echo "[$(date -Iseconds)] State preserved cleanly. Run /root/migration_swarm.sh to resume."
    exit 130
}
trap cleanup SIGINT SIGTERM

ATTEMPT=1

# Fault-Recovery Loop: Loops until rclone exits with code 0
until rclone sync "${SRC_REMOTE}" "${DST_REMOTE}" \
    --transfers=16 \
    --checkers=16 \
    --drive-chunk-size=128M \
    --buffer-size=64M \
    --protondrive-enable-caching \
    --tpslimit=4 \
    --tpslimit-burst=4 \
    --retries=10 \
    --retries-sleep=10s \
    --low-level-retries=10 \
    --track-renames \
    --update \
    --use-mmap \
    --stats=10s \
    --stats-one-line \
    --log-file="${LOG_FILE}" \
    --log-level=INFO; do
    
    EXIT_CODE=$?
    echo "[$(date -Iseconds)] WARNING: Sync iteration #${ATTEMPT} failed with exit code ${EXIT_CODE}."
    echo "[$(date -Iseconds)] Network drop or API rate-limit detected."
    echo "[$(date -Iseconds)] Sleeping for ${COOLDOWN_SECONDS} seconds before auto-resuming..."
    
    sleep "${COOLDOWN_SECONDS}"
    ATTEMPT=$((ATTEMPT + 1))
    echo "[$(date -Iseconds)] Restarting migration swarm (Iteration #${ATTEMPT})..."
done

echo "=============================================================================="
echo "[$(date -Iseconds)] SUCCESS: 700GB Proton Drive migration completed cleanly!"
echo "=============================================================================="
rm -f "$LOCK_FILE"
exit 0
