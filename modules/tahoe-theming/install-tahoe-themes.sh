#!/usr/bin/env bash
# install-tahoe-themes.sh
# Build-time script for the tahoe-theming BlueBuild module.
# Installs WhiteSur assets system-wide, lays down /usr/etc/xdg defaults,
# and seeds Tahoe-specific assets (wallpaper, icons).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Copy static XDG defaults and helper service
# ---------------------------------------------------------------------------
mkdir -p /usr/etc/xdg
if [[ -d "${SCRIPT_DIR}/defaults/xdg" ]]; then
  cp -aT "${SCRIPT_DIR}/defaults/xdg" /usr/etc/xdg
fi

install -Dm755 "${SCRIPT_DIR}/tahoe-cosmetic-reset" /usr/bin/tahoe-cosmetic-reset
install -Dm644 "${SCRIPT_DIR}/tahoe-cosmetic-reset.service" \
  /usr/lib/systemd/user/tahoe-cosmetic-reset.service

# ---------------------------------------------------------------------------
# Tahoe asset directory
# ---------------------------------------------------------------------------
TAHOE_DIR="/usr/share/tahoe"
mkdir -p "${TAHOE_DIR}/icons" "${TAHOE_DIR}/wallpapers"

# ---------------------------------------------------------------------------
# Simple Apple-logo "start-here" SVG
# ---------------------------------------------------------------------------
cat > "${TAHOE_DIR}/icons/start-here.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <path fill="#ffffff" d="M62.4 34.6c3.6-4.8 6.1-11.2 5.4-17.8-5.3.3-11.7 3.5-15.5 8.3-3.3 4.2-6.2 10.9-5.4 17.3 5.8.5 11.7-3 15.5-7.8zm18.5 8.3c-1.4-.8-3-1.2-4.6-1.2-4.4 0-8.1 2.6-10.4 2.6-2.4 0-6-2.5-10-2.5-5.2 0-10.1 3-12.8 7.7-5.5 9.5-1.4 23.6 3.9 31.3 2.6 3.8 5.7 8 9.8 7.9 3.9-.1 5.4-2.5 10.2-2.5 4.8 0 6.1 2.5 10.3 2.4 4.2-.1 6.9-3.9 9.5-7.7 3-4.3 4.2-8.5 4.3-8.7-.1 0-8.3-3.2-8.3-12.6 0-7.9 6.5-11.7 6.8-11.9-3.7-5.4-9.5-6-11.6-6.1-5.2-.2-9.7 2.8-12.1 2.8z"/>
</svg>
EOF

# ---------------------------------------------------------------------------
# Simple dark Safari compass icon SVG
# ---------------------------------------------------------------------------
cat > "${TAHOE_DIR}/icons/safari-dark.svg" <<'EOF'
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

# ---------------------------------------------------------------------------
# Static OLED-friendly wallpaper (dark blue/purple radial glow)
# ---------------------------------------------------------------------------
if command -v convert &>/dev/null; then
  convert -size 3840x2160 radial-gradient:#0f1a3a-#050505 \
    "${TAHOE_DIR}/wallpapers/default.png" || true
fi

# If ImageMagick is unavailable, ship a tiny black PNG as fallback.
if [[ ! -f "${TAHOE_DIR}/wallpapers/default.png" ]]; then
  python3 - <<'PY'
import struct, zlib
w, h = 3840, 2160
raw = b'\x00\x00\x00' * (w * h)
compressed = zlib.compress(raw)
def chunk(t, d):
    return t + struct.pack('>I', len(d)) + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', compressed)
png += chunk(b'IEND', b'')
open('/usr/share/tahoe/wallpapers/default.png', 'wb').write(png)
PY
fi

# ---------------------------------------------------------------------------
# Download and install WhiteSur icon, cursor, and KDE themes
# ---------------------------------------------------------------------------
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

download_tar() {
  local url="$1"
  local out="$2"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$out"
}

# WhiteSur icon theme
mkdir -p "${TMPDIR}/icons"
download_tar "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz" \
  "${TMPDIR}/icons/whitesur-icons.tar.gz"
tar -xzf "${TMPDIR}/icons/whitesur-icons.tar.gz" -C "${TMPDIR}/icons"
cd "${TMPDIR}/icons/WhiteSur-icon-theme-master"
./install.sh -d /usr/share/icons

# WhiteSur cursor theme
mkdir -p "${TMPDIR}/cursors"
download_tar "https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz" \
  "${TMPDIR}/cursors/whitesur-cursors.tar.gz"
tar -xzf "${TMPDIR}/cursors/whitesur-cursors.tar.gz" -C "${TMPDIR}/cursors"
cd "${TMPDIR}/cursors/WhiteSur-cursors-master"
if [[ -x ./install.sh ]]; then
  ./install.sh -d /usr/share/icons
fi

# WhiteSur KDE Plasma / Aurorae / Kvantum themes
mkdir -p "${TMPDIR}/kde"
download_tar "https://github.com/vinceliuice/WhiteSur-kde/archive/refs/heads/master.tar.gz" \
  "${TMPDIR}/kde/whitesur-kde.tar.gz"
tar -xzf "${TMPDIR}/kde/whitesur-kde.tar.gz" -C "${TMPDIR}/kde"
cd "${TMPDIR}/kde/WhiteSur-kde-master"
./install.sh

# ---------------------------------------------------------------------------
# Patch panel backgrounds to true black
# ---------------------------------------------------------------------------
PLASMA_THEME="/usr/share/plasma/desktoptheme/WhiteSur-dark"
if [[ -d "$PLASMA_THEME" ]]; then
  for variant in opaque solid translucent; do
    svgz="${PLASMA_THEME}/${variant}/widgets/panel-background.svgz"
    if [[ -f "$svgz" ]]; then
      tmp="${TMPDIR}/panel-bg.svg"
      gzip -cd "$svgz" > "$tmp"
      # Force common dark grays to pure black while preserving structure.
      sed -i -E \
        -e 's/#2[0-9a-fA-F]{5}/#000000/g' \
        -e 's/#3[0-9a-fA-F]{5}/#000000/g' \
        -e 's/#1[0-9a-fA-F]{5}/#000000/g' \
        -e 's/fill:[[:space:]]*#[0-9a-fA-F]{3,6}/fill:#000000/g' \
        "$tmp"
      gzip -c "$tmp" > "$svgz"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Patch Aurorae decoration to true black
# ---------------------------------------------------------------------------
for aurorae in /usr/share/aurorae/themes/WhiteSur-dark*; do
  [[ -d "$aurorae" ]] || continue
  dec="${aurorae}/decoration.svg"
  decz="${aurorae}/decoration.svgz"
  for f in "$dec" "$decz"; do
    if [[ -f "$f" ]]; then
      tmp="${TMPDIR}/decoration.svg"
      if [[ "$f" == *.svgz ]]; then
        gzip -cd "$f" > "$tmp"
      else
        cp "$f" "$tmp"
      fi
      sed -i -E \
        -e 's/#2[0-9a-fA-F]{5}/#000000/g' \
        -e 's/#3[0-9a-fA-F]{5}/#000000/g' \
        -e 's/#1[0-9a-fA-F]{5}/#000000/g' \
        -e 's/fill:[[:space:]]*#[0-9a-fA-F]{3,6}/fill:#000000/g' \
        "$tmp"
      if [[ "$f" == *.svgz ]]; then
        gzip -c "$tmp" > "$f"
      else
        cp "$tmp" "$f"
      fi
    fi
  done
done

# ---------------------------------------------------------------------------
# Update system-wide kwinrc default to use the x1.25 Aurorae variant
# ---------------------------------------------------------------------------
sed -i 's/theme=__aurorae__svg__WhiteSur-dark/theme=__aurorae__svg__WhiteSur-dark_x1.25/' \
  /usr/etc/xdg/kwinrc

# ---------------------------------------------------------------------------
# Update icon caches
# ---------------------------------------------------------------------------
for theme_dir in /usr/share/icons/WhiteSur /usr/share/icons/WhiteSur-dark /usr/share/icons/WhiteSur-light /usr/share/icons/WhiteSur-cursors; do
  if [[ -d "$theme_dir" ]]; then
    gtk-update-icon-cache -f "$theme_dir" || true
  fi
done
