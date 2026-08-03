#!/usr/bin/env bash
# g16-oled-dim.sh - Software gamma dimming for the ASUS ROG Zephyrus G16 OLED panel.
# Uses KWin Night Color when available and falls back to xrandr / xgamma on X11.
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Runtime/user-facing tool — no build-phase commands required.
# <MANIFEST_END>

exit 0

# --- SPDM AST Construction Engine ---
goto_script_logic() {
  local script_path="$1"
  awk '
    BEGIN { in_manifest=0; cmd=""; }
    /^# <MANIFEST_START>/ { in_manifest=1; next; }
    /^# <MANIFEST_END>/ { in_manifest=0; next; }
    in_manifest == 0 { next; }
    /^[[:space:]]*#/ { next; }
    /^[[:space:]]*$/ {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
      next;
    }
    {
      if (cmd == "") cmd = $0;
      else cmd = cmd " " $0;
      if (substr(cmd, length(cmd), 1) == "\\") {
        cmd = substr(cmd, 1, length(cmd)-1) " ";
      } else {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
    }
    END {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
      }
    }
  ' "$script_path"
}

# --- ORIGINAL SCRIPT LOGIC ---
set -euo pipefail

SCRIPT_NAME="g16-oled-dim.sh"
DEFAULT_BRIGHTNESS=70

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [BRIGHTNESS]

Apply software gamma dimming to help reduce OLED burn-in and eye strain.

  BRIGHTNESS   Integer 0-100 (default: ${DEFAULT_BRIGHTNESS})
  --help, -h   Show this help message

Examples:
  ${SCRIPT_NAME}        # dim to 70%
  ${SCRIPT_NAME} 50     # dim to 50%
  ${SCRIPT_NAME} 100    # reset to full brightness
EOF
}

brightness_to_temperature() {
    local brightness="$1"
    local temp
    temp=$(( 2500 + (brightness * 40) ))
    if [[ "${temp}" -gt 6500 ]]; then
        temp=6500
    fi
    echo "${temp}"
}

set_kwin_nightcolor() {
    local brightness="$1"
    local temperature
    temperature=$(brightness_to_temperature "${brightness}")

    local qdbus_bin=""
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus_bin="qdbus6"
    elif command -v qdbus >/dev/null 2>&1; then
        qdbus_bin="qdbus"
    else
        return 1
    fi

    local service="org.kde.KWin"
    local path="/ColorCorrect"
    local iface="org.kde.KWin.ColorCorrect"

    ${qdbus_bin} "${service}" "${path}" >/dev/null 2>&1 || return 1

    ${qdbus_bin} "${service}" "${path}" "org.freedesktop.DBus.Properties.Set" \
        "${iface}" nightColorActive true >/dev/null 2>&1 || true
    ${qdbus_bin} "${service}" "${path}" "org.freedesktop.DBus.Properties.Set" \
        "${iface}" nightColorTemperature "${temperature}" >/dev/null 2>&1 || return 1

    echo "Set KWin Night Color to ${temperature}K (brightness ${brightness}%)"
    return 0
}

set_xrandr_brightness() {
    local gamma="$1"
    if ! command -v xrandr >/dev/null 2>&1; then
        return 1
    fi

    local outputs
    outputs=$(xrandr | awk '/ connected / {print $1}')
    if [[ -z "${outputs}" ]]; then
        return 1
    fi

    while IFS= read -r output; do
        [[ -z "${output}" ]] && continue
        xrandr --output "${output}" --brightness "${gamma}"
        echo "Set xrandr brightness ${gamma} on ${output}"
    done <<< "${outputs}"
    return 0
}

set_xgamma() {
    local gamma="$1"
    if ! command -v xgamma >/dev/null 2>&1; then
        return 1
    fi
    xgamma -gamma "${gamma}"
    echo "Set xgamma to ${gamma}"
}

main() {
    local brightness="${DEFAULT_BRIGHTNESS}"

    case "${1:-}" in
        --help|-h)
            usage
            exit 0
            ;;
        "")
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                brightness="$1"
            else
                echo "Invalid brightness: $1" >&2
                usage >&2
                exit 1
            fi
            ;;
    esac

    if [[ "${brightness}" -lt 0 || "${brightness}" -gt 100 ]]; then
        echo "Brightness must be between 0 and 100 (got ${brightness})" >&2
        exit 1
    fi

    local gamma
    gamma=$(awk -v b="${brightness}" 'BEGIN { printf "%.2f", b / 100 }')

    echo "Applying OLED dimming: ${brightness}% (gamma ${gamma})"

    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]] && set_kwin_nightcolor "${brightness}"; then
        exit 0
    fi

    if set_xrandr_brightness "${gamma}"; then
        exit 0
    fi

    if set_xgamma "${gamma}"; then
        exit 0
    fi

    echo "No supported dimming method found (KWin Night Color, xrandr, or xgamma)." >&2
    exit 1
}

main "$@"
