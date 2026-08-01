#!/bin/bash
# Pre-start cleanup: remove stale Rigel miner processes left over from a
# previous container run before systemd starts a new alph-miner container.
# Only processes owned by the current user and whose process name is exactly
# "rigel" or "rigel-1.23.2-linux" are targeted.

set -euo pipefail

UID_VAL="$(id -u)"
USER_NAME="$(id -un)"

for name in rigel rigel-1.23.2-linux; do
    # List candidate PIDs by exact command name and same user.
    mapfile -t pids < <(ps -eo user:32,pid,stat,comm --no-header | awk -v u="$USER_NAME" -v n="$name" -v z='^Z' '$1 == u && $4 == n && $3 !~ z {print $2}')
    if [[ ${#pids[@]} -gt 0 ]]; then
        # Defensive: never kill the cleanup script itself (comm is bash).
        for pid in "${pids[@]}"; do
            if [[ "$pid" -eq "$$" ]]; then
                continue
            fi
            kill -9 "$pid" 2>/dev/null || true
        done
    fi
done

exit 0
