#!/bin/bash
# Restart alph-miner if GPU utilization stays at 0% while the service is active,
# or if stale/duplicate Rigel miner processes are detected.

set -euo pipefail

LOGFILE="${HOME}/gpu_watchdog.log"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
COUNTER_FILE="${RUN_DIR}/gpu_watchdog_zero_counter"
LAST_RESTART_FILE="${RUN_DIR}/gpu_watchdog_last_restart"
COOLDOWN_SEC=300
STRIKES=3

log_msg() {
    echo "[$(date -Iseconds)] $*" >> "$LOGFILE"
}

log_podman_context() {
    {
        echo "--- nvidia-smi ---"
        nvidia-smi 2>&1 || echo "nvidia-smi failed"
        echo "--- last 30 podman logs for alph-miner ---"
        podman logs --tail 30 alph-miner 2>&1 || echo "podman logs failed"
        echo "--- end diagnostics ---"
    } >> "$LOGFILE"
}

# Count real (non-defunct) Rigel miner processes owned by this user.
# Multi-Miner spawns a small "/miner/rigel" wrapper that execs the real
# "/miner/rigel-1.23.2-linux/rigel" binary.  The wrapper is not a duplicate;
# we count only the actual miner binary processes.  Anything >1 means an
# orphan/duplicate miner is still alive.
count_real_rigel() {
    ps -eo user:32,pid,stat,comm,args --no-header | awk -v me="$(id -un)" -v u="$(id -u)" '
        ($1 == me || $1 == u) && $4 == "rigel" && $3 !~ /^Z/ && $0 ~ /\/rigel-1\.23\.2-linux\/rigel/ {
            count++
        }
        END { print count + 0 }
    '
}

kill_user_rigel() {
    # -x matches the exact process name, so the watchdog script (comm=bash)
    # and the systemd unit can never be hit by these patterns.
    pkill -9 -x -u "$(id -u)" rigel 2>/dev/null || true
    pkill -9 -x -u "$(id -u)" rigel-1.23.2-linux 2>/dev/null || true
}

restart_miner() {
    local reason="$1"
    local now
    now=$(date +%s)
    local last=0
    if [[ -f "$LAST_RESTART_FILE" ]]; then
        last=$(cat "$LAST_RESTART_FILE" 2>/dev/null || echo 0)
    fi

    if [[ $((now - last)) -lt $COOLDOWN_SEC ]]; then
        log_msg "Cooldown active ($((now - last))s < ${COOLDOWN_SEC}s); skipping restart: $reason"
        return 1
    fi

    log_msg "$reason"
    log_podman_context
    kill_user_rigel
    systemctl --user restart alph-miner || true
    echo "$now" > "$LAST_RESTART_FILE"
    echo 0 > "$COUNTER_FILE" 2>/dev/null || true
    return 0
}

# Only act if alph-miner is supposed to be running.
if ! systemctl --user is-active --quiet alph-miner; then
    echo 0 > "$COUNTER_FILE" 2>/dev/null || true
    exit 0
fi

# Detect orphan/duplicate Rigel processes.
rigel_count=$(count_real_rigel)
if [[ "$rigel_count" -gt 1 ]]; then
    log_msg "Detected $rigel_count real rigel processes; killing duplicates"
    kill_user_rigel
    restart_miner "Restarting alph-miner due to duplicate rigel processes"
    exit 0
fi

# Sample GPU utilization.
utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '[:space:]' || true)

if [[ -z "$utilization" ]] || ! [[ "$utilization" =~ ^[0-9]+$ ]]; then
    log_msg "nvidia-smi returned invalid utilization (${utilization:-empty}); ignoring sample"
    exit 0
fi

count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

if [[ "$utilization" -eq 0 ]]; then
    count=$((count + 1))
    log_msg "GPU utilization 0% (strike $count/$STRIKES)"
    if [[ "$count" -ge "$STRIKES" ]]; then
        restart_miner "Restarting alph-miner due to 0% GPU utilization"
        count=0
    fi
else
    if [[ "$count" -ne 0 ]]; then
        log_msg "GPU utilization back to ${utilization}%"
    fi
    count=0
fi

echo "$count" > "$COUNTER_FILE"
