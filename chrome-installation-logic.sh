#!/usr/bin/env bash
# SPDM Constitution: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/SPDM_CONSTITUTION.md
# Coding Agent Baseline: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/CONTRIBUTING_Coding_Agent.md
# GITHUB_PAT: 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
# Branch: arch/spdm-refactor
# Target: Google Chrome Managed Flatpak Installation
# Hardware: ASUS ROG Zephyrus G16
#
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Install Google Chrome Flatpak package
run0 flatpak install -y flathub com.google.Chrome

# Apply Flatpak isolation overrides specifically for com.google.Chrome
run0 flatpak override --nofilesystem=xdg-documents --nofilesystem=xdg-music --nofilesystem=xdg-videos --nofilesystem=xdg-pictures --nosocket=x11 com.google.Chrome

# Disable LD_PRELOAD hardened_malloc for Chrome to avoid process crashes
run0 flatpak override --unset-env=LD_PRELOAD com.google.Chrome

# Ensure Ozone platform hint and VAAPI hardware video decoding flags exist in skel
mkdir -p /etc/skel/.var/app/com.google.Chrome/config

# Configure ozone platform and VAAPI hwdec flags for Chrome
echo "--ozone-platform-hint=auto" > /etc/skel/.var/app/com.google.Chrome/config/chrome-flags.conf

# Enable VAAPI hardware video decode in chrome config
echo "--enable-features=VaapiVideoDecodeLinuxGL" >> /etc/skel/.var/app/com.google.Chrome/config/chrome-flags.conf

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
'
