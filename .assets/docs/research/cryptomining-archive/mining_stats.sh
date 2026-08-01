#!/bin/bash
# mining_stats.sh - logs mining container status and recent logs every 15 minutes

set -euo pipefail

LOG_FILE="${HOME}/mining_stats.log"
INTERVAL=900

log_cmd() {
    local prefix
    prefix="[$(date +%s)] [$(date '+%Y-%m-%d %H:%M:%S %Z')]"
    "$@" 2>&1 | while IFS= read -r line; do
        printf '%s %s\n' "$prefix" "$line" >> "$LOG_FILE"
    done || true
}

log_msg() {
    printf '[%s] [%s] %s\n' \
        "$(date +%s)" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$1" >> "$LOG_FILE"
}

cleanup() {
    log_msg "mining_stats.sh: received termination signal, exiting."
    exit 0
}
trap cleanup SIGTERM SIGINT

log_msg "mining_stats.sh: starting logger."

while true; do
    log_msg "=== Mining stats block start ==="

    log_msg "--- systemctl --user status xmr-miner alph-miner ---"
    log_cmd systemctl --user status xmr-miner alph-miner --no-pager -l

    log_msg "--- podman logs --tail 30 xmr-miner ---"
    log_cmd podman logs --tail 30 xmr-miner

    log_msg "--- podman logs --tail 30 alph-miner ---"
    log_cmd podman logs --tail 30 alph-miner

    log_msg "=== Mining stats block end ==="
    printf '\n' >> "$LOG_FILE"

    sleep "$INTERVAL"
done
