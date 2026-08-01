#!/usr/bin/env bash
# agentic-workspace-init.sh
# Username-agnostic persistent workspace bootstrap.
# Creates a per-user workspace under /var/lib/agentic-os/<user> and symlinks
# it as ~/Agentic-OS so project state survives reboots and rebases.
#
# Canonical project path: ~/Agentic-OS/SecureBlue-KDE-Agentic-Deploy
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Create persistent workspace root directory for all users
mkdir -p /var/lib/agentic-os
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

readonly USER_NAME="${USER:-$(id -un)}"
readonly PERSIST_ROOT="/var/lib/agentic-os"
readonly USER_WORKSPACE="${PERSIST_ROOT}/${USER_NAME}"
readonly LINK_PATH="${HOME}/Agentic-OS"

mkdir -p "${USER_WORKSPACE}"

if [[ -L "${LINK_PATH}" ]]; then
    current_target="$(readlink -f "${LINK_PATH}" || true)"
    if [[ "${current_target}" != "${USER_WORKSPACE}" ]]; then
        rm "${LINK_PATH}"
        ln -s "${USER_WORKSPACE}" "${LINK_PATH}"
    fi
elif [[ -e "${LINK_PATH}" ]]; then
    echo "Agentic-OS path exists but is not a symlink; leaving it untouched." >&2
    exit 0
else
    ln -s "${USER_WORKSPACE}" "${LINK_PATH}"
fi
