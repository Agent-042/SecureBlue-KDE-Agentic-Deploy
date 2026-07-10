#!/usr/bin/env bash
# install-tahoe-themes.sh
# Build-time script for the tahoe-theming BlueBuild module.
# Installs WhiteSur assets system-wide, lays down /usr/etc/xdg defaults,
# and seeds Tahoe-specific assets (wallpaper, icons).
set -euo pipefail

# BlueBuild mounts the repo's ./files/ directory at /tmp/files/ during image build.
# Supporting Tahoe assets live in files/tahoe-theming/.
FILES_ROOT="/tmp/files"
TAHOE_SRC="${FILES_ROOT}/tahoe-theming"

# Guard against running outside the BlueBuild container (e.g. local testing).
# Fall back to the in-repo files/ tree so the script can be exercised manually.
if [[ ! -d "$TAHOE_SRC" ]]; then
  echo "[tahoe] BlueBuild staging path ${TAHOE_SRC} missing; falling back to ./files/"
  FILES_ROOT="./files"
  TAHOE_SRC="${FILES_ROOT}/tahoe-theming"
fi

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Add Klassy COPR repository (C++ binary window decoration)
# Replaces Aurorae SVG engine to eliminate fractional scaling artifacts
# ---------------------------------------------------------------------------
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

# Add applet-window-buttons COPR (stoplights in top panel for maximized windows)
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
rpm-ostree install -y klassy applet-window-buttons || true

# ---------------------------------------------------------------------------
# Flatpak overrides: map host GTK CSS into sandbox for consistent CSD theming
# ---------------------------------------------------------------------------
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro || true

# Copy static XDG defaults and helper service
# ---------------------------------------------------------------------------
mkdir -p /usr/etc/xdg
if [[ -d "${TAHOE_SRC}/defaults/xdg" ]]; then
  cp -aT "${TAHOE_SRC}/defaults/xdg" /usr/etc/xdg
fi

# Also seed the same defaults into /etc/skel/.config so live USB / new users
# get the Tahoe look before first login without relying on the helper service.
mkdir -p /etc/skel/.config
if [[ -d "${TAHOE_SRC}/defaults/xdg" ]]; then
  cp -aT "${TAHOE_SRC}/defaults/xdg" /etc/skel/.config
fi

install -Dm755 "${TAHOE_SRC}/tahoe-cosmetic-reset" /usr/bin/tahoe-cosmetic-reset
install -Dm644 "${TAHOE_SRC}/tahoe-cosmetic-reset.service" \
  /usr/lib/systemd/user/tahoe-cosmetic-reset.service
install -Dm755 "${TAHOE_SRC}/tahoe-gap-optimizer" /usr/bin/tahoe-gap-optimizer

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
  # WhiteSur-cursors install.sh uses the root/user default destination;
  # running it without arguments installs to /usr/share/icons as root.
  ./install.sh
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
      # Force panel backgrounds to true-black (#000000, opacity=1)
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

# ---------------------------------------------------------------------------
# Kvantum version guard: Kvantum 1.1.7 + Qt 6.11+ crashes Plasma on Wayland
# when compositing is enabled. Force it off for that version.
# ---------------------------------------------------------------------------
KVANTUM_CONFIG="/usr/etc/xdg/Kvantum/kvantum.kvconfig"
if [[ -f "$KVANTUM_CONFIG" ]]; then
  kvantum_version=""
  if command -v rpm >/dev/null 2>&1; then
    kvantum_version=$(rpm -q --queryformat '%{VERSION}' kvantum 2>/dev/null || true)
  fi
  if [[ -z "$kvantum_version" ]] && command -v dpkg >/dev/null 2>&1; then
    kvantum_version=$(dpkg-query -W -f='${Version}' kvantum 2>/dev/null || true)
  fi

  if [[ "$kvantum_version" == "1.1.7" ]]; then
    mkdir -p /usr/etc/xdg/Kvantum
    if grep -q '^\s*composite\s*=' "$KVANTUM_CONFIG" 2>/dev/null; then
      sed -i 's/^\s*composite\s*=.*/composite=false/' "$KVANTUM_CONFIG"
    else
      echo "composite=false" >> "$KVANTUM_CONFIG"
    fi
    if grep -q '^\s*translucent_windows\s*=' "$KVANTUM_CONFIG" 2>/dev/null; then
      sed -i 's/^\s*translucent_windows\s*=.*/translucent_windows=false/' "$KVANTUM_CONFIG"
    else
      echo "translucent_windows=false" >> "$KVANTUM_CONFIG"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Inject Tahoe dock layout.js as the system default
# Overwrites the default KDE panel layout with macOS-style dock
# ---------------------------------------------------------------------------
LAYOUT_SRC="/tmp/files/tahoe-theming/layout-templates"
LAYOUT_DST="/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents"
SHELL_DST="/usr/share/plasma/shells/org.kde.plasma.desktop/contents"

if [[ -f "${LAYOUT_SRC}/org.kde.plasma.desktop.defaultPanel/contents/layout.js" ]]; then
    mkdir -p "${LAYOUT_DST}"
    cp -f "${LAYOUT_SRC}/org.kde.plasma.desktop.defaultPanel/contents/layout.js" \
        "${LAYOUT_DST}/layout.js"
    echo "[tahoe] Injected dock layout.js into defaultPanel template"
fi

if [[ -f "${LAYOUT_SRC}/org.kde.plasma.desktop/contents/layout.js" ]]; then
    mkdir -p "${SHELL_DST}"
    cp -f "${LAYOUT_SRC}/org.kde.plasma.desktop/contents/layout.js" \
        "${SHELL_DST}/layout.js"
    echo "[tahoe] Injected dock layout.js into desktop shell"
fi

# ---------------------------------------------------------------------------
# Inject desktop shell layout with top panel + window buttons + dock
# ---------------------------------------------------------------------------
SHELL_SRC="/tmp/files/tahoe-theming/shells"
SHELL_DST="/usr/share/plasma/shells/org.kde.plasma.desktop/contents"

if [[ -f "${SHELL_SRC}/org.kde.plasma.desktop/contents/layout.js" ]]; then
    mkdir -p "${SHELL_DST}"
    cp -f "${SHELL_SRC}/org.kde.plasma.desktop/contents/layout.js" \
        "${SHELL_DST}/layout.js"
    echo "[tahoe] Injected desktop shell layout with top panel + window buttons"
fi

# ---------------------------------------------------------------------------
# Convert bundled macOS .icns files to PNGs for KDE Plasma
# ---------------------------------------------------------------------------
sanitize_icon_name() {
    local name="$1"
    # Strip extension, lowercase, replace spaces/special chars with underscores
    name="${name%.icns}"
    name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
    name=$(printf '%s' "$name" | sed -e 's/[^a-z0-9._-]/_/g' -e 's/__*/_/g' -e 's/^_//' -e 's/_$//')
    printf '%s.png' "$name"
}

convert_macos_icns() {
    local src_dir="${FILES_ROOT}/assets/macos-icons/top_50_mac_icons"
    local dst_dir="/usr/share/icons/hicolor/512x512/apps"

    [[ -d "$src_dir" ]] || {
        echo "[tahoe] No bundled .icns source directory at ${src_dir}; skipping conversion"
        return 0
    }

    mkdir -p "$dst_dir"

    local converter=""
    if command -v icns2png &>/dev/null; then
        converter="icns2png"
    elif command -v convert &>/dev/null; then
        converter="convert"
    else
        echo "[tahoe] No icns2png or ImageMagick convert available; skipping .icns conversion"
        return 0
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    for icns in "$src_dir"/*.icns; do
        [[ -f "$icns" ]] || continue
        local base out_name out_path
        base=$(basename "$icns")
        out_name=$(sanitize_icon_name "$base")
        out_path="${dst_dir}/${out_name}"

        if [[ "$converter" == "icns2png" ]]; then
            # Try the exact 512x512 size first
            rm -f "$tmpdir"/*.png
            if icns2png -x -s 512x512 -o "$tmpdir" "$icns" &>/dev/null; then
                local extracted
                extracted=$(ls -S "$tmpdir"/*.png 2>/dev/null | head -n1)
                if [[ -f "$extracted" ]]; then
                    mv "$extracted" "$out_path"
                    echo "[tahoe] Converted .icns (512): ${base} -> ${out_name}"
                    continue
                fi
            fi

            # Fall back to extracting the largest available size
            rm -f "$tmpdir"/*.png
            if icns2png -x -o "$tmpdir" "$icns" &>/dev/null; then
                local extracted
                extracted=$(ls -S "$tmpdir"/*.png 2>/dev/null | head -n1)
                if [[ -f "$extracted" ]]; then
                    if command -v convert &>/dev/null; then
                        convert "$extracted" -resize 512x512 "$out_path" 2>/dev/null
                    else
                        mv "$extracted" "$out_path"
                    fi
                    echo "[tahoe] Converted .icns (resize): ${base} -> ${out_name}"
                fi
            fi
        else
            # ImageMagick fallback
            if convert "$icns" -resize 512x512 "$out_path" 2>/dev/null; then
                echo "[tahoe] Converted .icns (convert): ${base} -> ${out_name}"
            fi
        fi
    done

    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
}

convert_macos_icns

# ---------------------------------------------------------------------------
# Install deterministic fallback icons for apps the scraper missed
# ---------------------------------------------------------------------------
install_fallback_icons() {
    local src_dir="${FILES_ROOT}/assets/macos-icons/fallbacks"
    local scalable_dir="/usr/share/icons/hicolor/scalable/apps"
    local png_dir="/usr/share/icons/hicolor/512x512/apps"

    [[ -d "$src_dir" ]] || return 0
    mkdir -p "$scalable_dir" "$png_dir"

    local svg
    for svg in "$src_dir"/*.svg; do
        [[ -f "$svg" ]] || continue
        local base
        base=$(basename "$svg")
        install -Dm644 "$svg" "${scalable_dir}/${base}"
        echo "[tahoe] Installed fallback SVG: ${base}"

        local png_out="${png_dir}/${base%.svg}.png"
        if command -v rsvg-convert &>/dev/null; then
            rsvg-convert -w 512 -h 512 "$svg" -o "$png_out" 2>/dev/null &&
                echo "[tahoe] Rendered fallback PNG (rsvg-convert): ${base%.svg}.png"
        elif command -v convert &>/dev/null; then
            convert "$svg" -resize 512x512 "$png_out" 2>/dev/null &&
                echo "[tahoe] Rendered fallback PNG (convert): ${base%.svg}.png"
        fi
    done
}

install_fallback_icons

# ---------------------------------------------------------------------------
# Run macOS icon scraper (if API key is available)
# ---------------------------------------------------------------------------
if [[ -x "${FILES_ROOT}/scripts/scrape-macos-icons.sh" ]]; then
    "${FILES_ROOT}/scripts/scrape-macos-icons.sh" || true
fi
