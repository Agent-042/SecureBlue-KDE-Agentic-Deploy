#!/usr/bin/env bash
# vibrant-linux-install.sh
# Download the upstream VibrantLinux binary and install a local desktop entry.
# If the upstream release URL is unavailable, use the KDE Night Color fallback
# documented below for software OLED dimming and color-temperature adjustment.
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

INSTALL_DIR="${HOME}/Agentic-OS/bin"
BIN_PATH="${INSTALL_DIR}/vibrantlinux"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_PATH="${DESKTOP_DIR}/vibrantlinux.desktop"

VIBRANT_LINUX_URL="${VIBRANT_LINUX_URL:-https://github.com/libvibrant/vibrantLinux/releases/download/PLACEHOLDER/vibrantlinux}"

mkdir -p "${INSTALL_DIR}" "${DESKTOP_DIR}"

echo "Downloading VibrantLinux to ${BIN_PATH} ..."
if ! curl -fsSL -o "${BIN_PATH}" "${VIBRANT_LINUX_URL}"; then
    echo "ERROR: Download failed for ${VIBRANT_LINUX_URL}" >&2
    echo "" >&2
    echo "VibrantLinux does not currently ship a stable standalone release at this URL." >&2
    echo "Alternatives:" >&2
    echo "  1. Set VIBRANT_LINUX_URL to a direct binary URL and rerun this script." >&2
    echo "  2. Install the Flathub build:" >&2
    echo "       flatpak install flathub io.github.libvibrant.vibrantLinux" >&2
    echo "  3. Use the KDE Night Color fallback for software dimming (see below)." >&2
    echo "" >&2
    echo "KDE Night Color fallback:" >&2
    echo "  Settings -> Display -> Night Color -> Enable -> set color temperature." >&2
    exit 1
fi

chmod +x "${BIN_PATH}"

cat > "${DESKTOP_PATH}" <<EOF
[Desktop Entry]
Name=VibrantLinux
Comment=Adjust display saturation and OLED dimming
Exec=${BIN_PATH}
Type=Application
Terminal=false
Icon=preferences-desktop-display
Categories=Settings;
EOF

echo "Installed VibrantLinux:"
echo "  Binary:          ${BIN_PATH}"
echo "  Desktop entry:   ${DESKTOP_PATH}"
echo ""
echo "Run it from the application menu or with:"
echo "  ${BIN_PATH}"
echo ""
echo "KDE Night Color fallback (software dimming / color temperature):"
echo "  Settings -> Display -> Night Color -> Enable -> choose a comfortable temperature."
