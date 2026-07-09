#!/usr/bin/env bash
# g16-rescue.sh - Emergency rescue helper for SecureBlue KDE deployments.
# Embedded in the image root to provide offline system status, network
# diagnostics, and a safe-mode network reset.

set -euo pipefail

SCRIPT_NAME="g16-rescue.sh"

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [COMMAND]

Emergency rescue helper for the local SecureBlue KDE system.

Commands:
  status      Show disk usage, booted deployment, and failed systemd units
  network     Run network diagnostics (nmcli, ip, ping)
  safe-mode   Reset network configuration and restart NetworkManager
  help        Show this help message

If no command is given, "status" is used.
EOF
}

cmd_status() {
    echo "=== Emergency Rescue: System Status ==="
    echo
    echo "--- Disk usage ---"
    df -h / /boot /var /home 2>/dev/null || df -h
    echo
    echo "--- Booted deployment ---"
    if command -v rpm-ostree >/dev/null 2>&1; then
        rpm-ostree status --booted
    else
        echo "rpm-ostree not available"
    fi
    echo
    echo "--- Failed systemd units ---"
    systemctl --failed --no-pager || true
}

cmd_network() {
    echo "=== Emergency Rescue: Network Diagnostics ==="
    echo
    echo "--- NetworkManager status ---"
    nmcli general status || echo "NetworkManager/nmcli not available"
    echo
    echo "--- Active connections ---"
    nmcli connection show --active || true
    echo
    echo "--- Device list ---"
    nmcli device show || true
    echo
    echo "--- IP addresses ---"
    ip -brief addr show || true
    echo
    echo "--- Routes ---"
    ip route show || true
    echo
    echo "--- DNS resolver ---"
    cat /etc/resolv.conf 2>/dev/null || true
    echo
    echo "--- Gateway reachability ---"
    local gateway
    gateway=$(ip route show | awk '/^default/ {print $3; exit}')
    if [[ -n "${gateway}" ]]; then
        ping -c 3 -W 3 "${gateway}" || echo "Gateway ${gateway} unreachable"
    else
        echo "No default gateway found"
    fi
    echo
    echo "--- External reachability ---"
    ping -c 3 -W 5 1.1.1.1 || echo "1.1.1.1 unreachable"
}

cmd_safe_mode() {
    echo "=== Emergency Rescue: Safe Mode Network Reset ==="
    echo "This will restart NetworkManager and reload all connection profiles."
    read -r -p "Continue? [y/N] " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "--- Restarting NetworkManager ---"
    if systemctl restart NetworkManager.service 2>/dev/null; then
        echo "NetworkManager restarted"
    elif command -v run0 >/dev/null 2>&1 && run0 systemctl restart NetworkManager.service; then
        echo "NetworkManager restarted (via run0)"
    else
        echo "Failed to restart NetworkManager" >&2
        exit 1
    fi

    echo "--- Reloading connection profiles ---"
    nmcli connection reload || true
    nmcli networking off || true
    sleep 1
    nmcli networking on || true

    echo "--- Safe mode reset complete ---"
    nmcli general status || true
}

main() {
    case "${1:-status}" in
        status|--status)
            cmd_status
            ;;
        network|--network)
            cmd_network
            ;;
        safe-mode|--safe-mode|safemode)
            cmd_safe_mode
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${1}" >&2
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
