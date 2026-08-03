#!/bin/bash
# Idle monitor for rootless Podman miner services.
#
# Preferred backend: swayidle.  If swayidle is missing, the script falls back to
# polling the active logind session's IdleHint.  (systemd-inhibit and
# loginctl idle-monitor are not idle *detectors*, so they cannot drive a
# configurable timeout; polling loginctl show-session is the most robust
# portable fallback.)
#
# Usage: idle_monitor.sh {start|stop|restart|run}

set -euo pipefail

IDLE_SECONDS=300
POLL_INTERVAL=10
REQUIRED_COUNTS=$((IDLE_SECONDS / POLL_INTERVAL))

RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.local/run}"
PIDFILE="$RUN_DIR/idle_monitor.pid"
LOGFILE="$RUN_DIR/idle_monitor.log"

SERVICES=(xmr-miner alph-miner)

mkdir -p "$(dirname "$PIDFILE")" "$(dirname "$LOGFILE")"

log_msg() {
  echo "[$(date -Iseconds)] $*" >>"$LOGFILE"
}

get_display_session() {
  local sess
  sess=$(loginctl show-user "$(whoami)" -p Display --value 2>/dev/null || true)
  if [[ -z "$sess" ]]; then
    sess=$(loginctl list-sessions --no-legend 2>/dev/null | awk 'NR==1{print $1}')
  fi
  printf '%s' "$sess"
}

start_miners() {
  log_msg "Idle threshold reached; starting ${SERVICES[*]}"
  systemctl --user start "${SERVICES[@]}" || log_msg "Failed to start miners"
}

stop_miners() {
  log_msg "Activity detected; stopping ${SERVICES[*]}"
  systemctl --user stop "${SERVICES[@]}" || log_msg "Failed to stop miners"
}

run_poll_loop() {
  trap 'rm -f "$PIDFILE"' EXIT

  local session idle_hint idle_count=0 miners_running=false
  session=$(get_display_session)
  if [[ -z "$session" ]]; then
    log_msg "ERROR: could not determine active logind session"
    exit 1
  fi

  log_msg "Monitoring session $session (poll ${POLL_INTERVAL}s, threshold ${IDLE_SECONDS}s)"

  while true; do
    idle_hint=$(loginctl show-session "$session" -p IdleHint --value 2>/dev/null || echo "no")

    if [[ "$idle_hint" == "yes" ]]; then
      ((idle_count++))
      if ((idle_count >= REQUIRED_COUNTS)) && [[ "$miners_running" == "false" ]]; then
        start_miners
        miners_running=true
      fi
    else
      idle_count=0
      if [[ "$miners_running" == "true" ]]; then
        stop_miners
        miners_running=false
      fi
    fi

    sleep "$POLL_INTERVAL"
  done
}

run_swayidle() {
  log_msg "Using swayidle"
  exec swayidle -w \
    timeout "$IDLE_SECONDS" 'systemctl --user start xmr-miner alph-miner' \
    resume 'systemctl --user stop xmr-miner alph-miner'
}

cmd_start() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    log_msg "idle_monitor already running (PID $(cat "$PIDFILE"))"
    return 0
  fi
  nohup "$0" run >>"$LOGFILE" 2>&1 &
  echo $! >"$PIDFILE"
  log_msg "daemon started (PID $!)"
}

cmd_stop() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  stop_miners
}

cmd_restart() {
  cmd_stop
  cmd_start
}

case "${1:-run}" in
  start)
    cmd_start
    ;;
  stop)
    cmd_stop
    ;;
  restart)
    cmd_restart
    ;;
  run)
    if command -v swayidle >/dev/null 2>&1; then
      run_swayidle
    else
      run_poll_loop
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|run}" >&2
    exit 1
    ;;
esac
