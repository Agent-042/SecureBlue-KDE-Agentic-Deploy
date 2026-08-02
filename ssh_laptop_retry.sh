#!/bin/bash
# Continuous SSH retry background service
LOGFILE="/var/log/ssh_laptop_retry.log"
exec >> "$LOGFILE" 2>&1

echo "[$(date)] Starting continuous SSH retry daemon for root@laptop..."

TARGETS=("laptop" "laptop.local" "172.17.17.68")

while true; do
    CONNECTED=0
    for TARGET in "${TARGETS[@]}"; do
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${TARGET}" "hostname" >/dev/null 2>&1; then
            echo "[$(date)] SUCCESS: SSHed into root@${TARGET}!"
            CONNECTED=1
            break
        fi
    done

    if [ $CONNECTED -eq 0 ]; then
        echo "[$(date)] Status: Waiting for laptop SSH endpoint... (retrying in 20s)"
    fi
    sleep 20
done
