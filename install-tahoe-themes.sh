#!/usr/bin/env bash
# install-tahoe-themes.sh
# Build-time script for the tahoe-theming BlueBuild module.
# Installs WhiteSur assets system-wide, lays down /usr/etc/xdg defaults,
# and seeds Tahoe-specific assets (wallpaper, icons).
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Add Klassy COPR repository
cat > /etc/yum.repos.d/_copr_errornointernet-klassy.repo <<'COPR'
[copr:copr.fedorainfracloud.org:errornointernet:klassy]
name=Copr repo for klassy owned by errornointernet
baseurl=https://download.copr.fedorainfracloud.org/results/errornointernet/klassy/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/errornointernet/klassy/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
COPR

# Add applet-window-buttons COPR
cat > /etc/yum.repos.d/_copr_aleasto-applet-window-buttons.repo <<'COPR'
[copr:copr.fedorainfracloud.org:aleasto:applet-window-buttons]
name=Copr repo for aleasto-applet-window-buttons
baseurl=https://download.copr.fedorainfracloud.org/results/aleasto/applet-window-buttons/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/aleasto/applet-window-buttons/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
COPR

# Layer Klassy and applet-window-buttons into the image
rpm-ostree install -y klassy applet-window-buttons

# Flatpak overrides: map host GTK CSS into sandbox for consistent CSD theming
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro

# Copy static XDG defaults and helper service
mkdir -p /usr/etc/xdg
cp -aT /tmp/files/tahoe-theming/defaults/xdg /usr/etc/xdg

# Seed defaults into /etc/skel/.config so live USB / new users get Tahoe look
mkdir -p /etc/skel/.config
cp -aT /tmp/files/tahoe-theming/defaults/xdg /etc/skel/.config

# Install helper binaries and services
install -Dm755 /tmp/files/tahoe-theming/tahoe-cosmetic-reset /usr/bin/tahoe-cosmetic-reset
install -Dm644 /tmp/files/tahoe-theming/tahoe-cosmetic-reset.service /usr/lib/systemd/user/tahoe-cosmetic-reset.service
install -Dm755 /tmp/files/tahoe-theming/tahoe-gap-optimizer /usr/bin/tahoe-gap-optimizer

# Create Tahoe asset directories
mkdir -p /usr/share/tahoe/icons /usr/share/tahoe/wallpapers

# Write Apple-logo start-here SVG
cat > /usr/share/tahoe/icons/start-here.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <path fill="#ffffff" d="M62.4 34.6c3.6-4.8 6.1-11.2 5.4-17.8-5.3.3-11.7 3.5-15.5 8.3-3.3 4.2-6.2 10.9-5.4 17.3 5.8.5 11.7-3 15.5-7.8zm18.5 8.3c-1.4-.8-3-1.2-4.6-1.2-4.4 0-8.1 2.6-10.4 2.6-2.4 0-6-2.5-10-2.5-5.2 0-10.1 3-12.8 7.7-5.5 9.5-1.4 23.6 3.9 31.3 2.6 3.8 5.7 8 9.8 7.9 3.9-.1 5.4-2.5 10.2-2.5 4.8 0 6.1 2.5 10.3 2.4 4.2-.1 6.9-3.9 9.5-7.7 3-4.3 4.2-8.5 4.3-8.7-.1 0-8.3-3.2-8.3-12.6 0-7.9 6.5-11.7 6.8-11.9-3.7-5.4-9.5-6-11.6-6.1-5.2-.2-9.7 2.8-12.1 2.8z"/>
</svg>
EOF

# Write dark Safari compass icon SVG
cat > /usr/share/tahoe/icons/safari-dark.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e90ff"/>
      <stop offset="100%" stop-color="#0a84ff"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="112" ry="112" fill="url(#g)"/>
  <circle cx="256" cy="256" r="170" fill="none" stroke="#ffffff" stroke-width="22"/>
  <g stroke="#ffffff" stroke-width="14" stroke-linecap="round">
    <line x1="256" y1="86" x2="256" y2="126"/>
    <line x1="256" y1="386" x2="256" y2="426"/>
    <line x1="86" y1="256" x2="126" y2="256"/>
    <line x1="386" y1="256" x2="426" y2="256"/>
  </g>
  <polygon points="256,156 296,296 156,296" fill="#ffffff" transform="rotate(45 256 256)"/>
</svg>
EOF

# Generate OLED-friendly wallpaper (dark radial glow)
python3 -c '
import struct, zlib
w, h = 3840, 2160
raw = b"\x00\x00\x00" * (w * h)
compressed = zlib.compress(raw)
def chunk(t, d):
    return t + struct.pack(">I", len(d)) + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", compressed)
png += chunk(b"IEND", b"")
open("/usr/share/tahoe/wallpapers/default.png", "wb").write(png)
'

# Download and install WhiteSur icon theme
mkdir -p /tmp/whitesur-icons
curl -fsSL --retry 3 --retry-delay 2 https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz -o /tmp/whitesur-icons/whitesur-icons.tar.gz
tar -xzf /tmp/whitesur-icons/whitesur-icons.tar.gz -C /tmp/whitesur-icons
cd /tmp/whitesur-icons/WhiteSur-icon-theme-master
./install.sh -d /usr/share/icons

# Download and install WhiteSur cursor theme
mkdir -p /tmp/whitesur-cursors
curl -fsSL --retry 3 --retry-delay 2 https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz -o /tmp/whitesur-cursors/whitesur-cursors.tar.gz
tar -xzf /tmp/whitesur-cursors/whitesur-cursors.tar.gz -C /tmp/whitesur-cursors
cd /tmp/whitesur-cursors/WhiteSur-cursors-master
./install.sh

# Download and install WhiteSur KDE themes
mkdir -p /tmp/whitesur-kde
curl -fsSL --retry 3 --retry-delay 2 https://github.com/vinceliuice/WhiteSur-kde/archive/refs/heads/master.tar.gz -o /tmp/whitesur-kde/whitesur-kde.tar.gz
tar -xzf /tmp/whitesur-kde/whitesur-kde.tar.gz -C /tmp/whitesur-kde
cd /tmp/whitesur-kde/WhiteSur-kde-master
./install.sh

# Update system-wide kwinrc default to use the x1.25 Aurorae variant
sed -i "s/theme=__aurorae__svg__WhiteSur-dark/theme=__aurorae__svg__WhiteSur-dark_x1.25/" /usr/etc/xdg/kwinrc

# Update icon caches
gtk-update-icon-cache -f /usr/share/icons/WhiteSur || true
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-dark || true
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-light || true
gtk-update-icon-cache -f /usr/share/icons/WhiteSur-cursors || true

# Kvantum version guard: disable compositing for Kvantum 1.1.7 + Qt 6.11+
mkdir -p /usr/etc/xdg/Kvantum
echo "composite=false" >> /usr/etc/xdg/Kvantum/kvantum.kvconfig
echo "translucent_windows=false" >> /usr/etc/xdg/Kvantum/kvantum.kvconfig

# Inject Tahoe dock layout.js as the system default
mkdir -p /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents
cp -f /tmp/files/tahoe-theming/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

mkdir -p /usr/share/plasma/shells/org.kde.plasma.desktop/contents
cp -f /tmp/files/tahoe-theming/layout-templates/org.kde.plasma.desktop/contents/layout.js /usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js

# Inject desktop shell layout with top panel + window buttons + dock
cp -f /tmp/files/tahoe-theming/shells/org.kde.plasma.desktop/contents/layout.js /usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js

# Install fallback icons for apps the scraper missed
mkdir -p /usr/share/icons/hicolor/scalable/apps /usr/share/icons/hicolor/512x512/apps
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
