#!/bin/bash
# Continuous SSH retry background service
LOGFILE="/var/log/ssh_laptop_retry.log"
exec >> "$LOGFILE" 2>&1

echo "[$(date)] Starting continuous SSH retry daemon for root@laptop..."

TARGETS=("laptop" "laptop.local" "172.17.17.68")

while true; do
    CONNECTED=0
    # PERFORMANCE OPTIMIZATION (Bolt ⚡): Parallelize connection checks.
    # Instead of checking targets sequentially (which takes up to 15 seconds of blocking timeout
    # when all are offline), we spawn them in parallel, capping the max timeout at 5 seconds.
    SUCCESS_FILE=$(mktemp)

    # Spawn SSH checks in parallel background jobs
    for TARGET in "${TARGETS[@]}"; do
        (
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${TARGET}" "hostname" >/dev/null 2>&1; then
                echo "${TARGET}" > "$SUCCESS_FILE"
            fi
        ) &
    done

    # Wait for all background checks to complete
    wait

    # Check if any target succeeded
    if [ -s "$SUCCESS_FILE" ]; then
        SUCCESSFUL_TARGET=$(cat "$SUCCESS_FILE")
        echo "[$(date)] SUCCESS: SSHed into root@${SUCCESSFUL_TARGET}!"
        CONNECTED=1
    fi
    rm -f "$SUCCESS_FILE"

    if [ $CONNECTED -eq 0 ]; then
        echo "[$(date)] Status: Waiting for laptop SSH endpoint... (retrying in 20s)"
    fi
    sleep 20
done
