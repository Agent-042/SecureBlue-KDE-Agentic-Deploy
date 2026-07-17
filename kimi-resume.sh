#!/usr/bin/env bash
# Kimi Code CLI workspace resume helper.
# Run this after first login on a fresh deployment to restore the project repo
# and verify that the persistent Agentic-OS workspace is linked.
#
# Why the source path is nested: this file is installed into the image by the
# BlueBuild files module at modules/kimi-resume/module.yml. The files/<module>/
# tree maps directly onto the image filesystem, so files/kimi-resume/usr/bin/
# becomes /usr/bin/ in the deployed image.
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

readonly REPO_URL="https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy.git"
readonly WORKSPACE_LINK="${HOME}/Agentic-OS"
readonly REPO_DIR="${WORKSPACE_LINK}/SecureBlue-KDE-Agentic-Deploy"

if [[ ! -L "${WORKSPACE_LINK}" ]]; then
    /usr/bin/agentic-workspace-init.sh
fi

if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "Updating existing repo at ${REPO_DIR}..."
    git -C "${REPO_DIR}" pull --ff-only
else
    echo "Cloning project repo into ${REPO_DIR}..."
    mkdir -p "${REPO_DIR}"
    git clone "${REPO_URL}" "${REPO_DIR}"
fi

if command -v kimi >/dev/null 2>&1; then
    echo "Kimi Code CLI: $(kimi --version 2>/dev/null || echo 'installed')"
else
    echo "Kimi Code CLI not found in PATH."
    echo "Install it manually (e.g., via the official installer) and re-run this script."
    echo "Session state in ~/.kimi-code/ should be backed up before any future immutability changes."
fi

echo "Resume complete. Project workspace: ${REPO_DIR}"
