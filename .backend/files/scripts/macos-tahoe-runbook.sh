#!/usr/bin/env bash
# macOS Tahoe Replica — Reproducible runbook for SecureBlue/Kinoite + KDE Plasma 6
# Canonical doc: /var/home/agent-42/macOS-Tahoe-Runbook.md
# Idempotent. Run as the desktop user.
set -euo pipefail

TAHOE_SCALE="${TAHOE_SCALE:-1.5}"
scale_int() { awk -v n="$1" -v s="$TAHOE_SCALE" 'BEGIN {v=n*s; print int(v+0.5)}'; }

TOP_THICKNESS=$(scale_int 26)
DOCK_THICKNESS=$(scale_int 50)
DOCK_ICON_SIZE=$(scale_int 48)
SYSTRAY_ICON_SIZE=$(scale_int 20)

HOME_DIR="$HOME"
WALLDIR="$HOME_DIR/Videos/RGB-Wallpapers"
DESKTOP_DIR="$HOME_DIR/.local/share/applications"
BIN_DIR="$HOME_DIR/.local/bin"
SERVICE_DIR="$HOME_DIR/.config/systemd/user"
PLASMA_RC="$HOME_DIR/.config/plasma-org.kde.plasma.desktop-appletsrc"
KLAUNCH_RC="$HOME_DIR/.config/klaunchrc"
KONSOLE_DIR="$HOME_DIR/.config/konsole"
ICON_DIR="$HOME_DIR/.local/share/icons"
AURORAE="$HOME_DIR/.local/share/aurorae/themes/WhiteSur-dark/WhiteSur-darkrc"

log() { echo "[runbook] $*"; }
die() { echo "[runbook] ERROR: $*" >&2; exit 1; }

ID_DISCOVER="$HOME_DIR/.local/bin/plasma-id-discover.py"
if [ ! -x "$ID_DISCOVER" ]; then
    die "ID discovery helper not found: $ID_DISCOVER"
fi
eval "$(python3 "$ID_DISCOVER")"

if [ -z "$WALL_CONTAINMENT" ] || [ -z "$TOP_CONTAINMENT" ] || [ -z "$DOCK_CONTAINMENT" ]; then
    die "Could not discover required Plasma containment IDs"
fi
log "Discovered containment IDs: wall=$WALL_CONTAINMENT top=$TOP_CONTAINMENT dock=$DOCK_CONTAINMENT"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
command -v python3 >/dev/null || die "python3 not found"
command -v kwriteconfig6 >/dev/null || die "kwriteconfig6 not found"
command -v ffmpeg >/dev/null || log "WARNING: ffmpeg not found; OLED fallback wallpapers will not be generated"
command -v magick >/dev/null || log "WARNING: ImageMagick not found; Safari dark icon will not be generated"

mkdir -p "$WALLDIR" "$DESKTOP_DIR" "$BIN_DIR" "$SERVICE_DIR" "$KONSOLE_DIR" \
         "$ICON_DIR/hicolor/512x512/apps" "$ICON_DIR/hicolor/scalable/apps"

# ---------------------------------------------------------------------------
# 1. Icons
# ---------------------------------------------------------------------------
setup_icons() {
    log "Installing custom icons ..."

    if [[ ! -f "$ICON_DIR/hicolor/512x512/apps/openhands.png" ]]; then
        curl -sL -o "$ICON_DIR/hicolor/512x512/apps/openhands.png" \
            "https://raw.githubusercontent.com/OpenHands/OpenHands/main/frontend/public/android-chrome-512x512.png" || true
    fi

    if [[ -f "$HOME_DIR/Downloads/dolphin3.jpeg" ]]; then
        magick "$HOME_DIR/Downloads/dolphin3.jpeg" -resize 512x512 \
            -fuzz 18% -transparent "rgb(255,255,255)" \
            -fuzz 18% -transparent "rgb(245,245,245)" \
            -fuzz 18% -transparent "rgb(235,235,235)" \
            "$ICON_DIR/hicolor/512x512/apps/dolphin3.png"
        for size in 256 128 96 64 48 32 24 22 16; do
            mkdir -p "$ICON_DIR/hicolor/${size}x${size}/apps"
            magick "$ICON_DIR/hicolor/512x512/apps/dolphin3.png" \
                -resize ${size}x${size} "$ICON_DIR/hicolor/${size}x${size}/apps/dolphin3.png"
        done
    fi

    rm -f "$ICON_DIR/WhiteSur/apps/scalable/dolphin3.svg" "$ICON_DIR/WhiteSur-dark/apps/scalable/dolphin3.svg"

    if command -v magick >/dev/null && [[ -f "$ICON_DIR/WhiteSur/apps/scalable/safari.svg" ]]; then
        magick "$ICON_DIR/WhiteSur/apps/scalable/safari.svg" -resize 512x512 -fill black -colorize 40% -modulate 75 \
            "$ICON_DIR/hicolor/512x512/apps/safari-dark.png"
        cp "$ICON_DIR/hicolor/512x512/apps/safari-dark.png" "$ICON_DIR/WhiteSur/apps/scalable/safari-dark.png"
        cp "$ICON_DIR/hicolor/512x512/apps/safari-dark.png" "$ICON_DIR/WhiteSur-dark/apps/scalable/safari-dark.png"
    fi

    cp "$ICON_DIR/hicolor/512x512/apps/openhands.png" "$ICON_DIR/WhiteSur/apps/scalable/openhands.png" 2>/dev/null || true
    cp "$ICON_DIR/hicolor/512x512/apps/openhands.png" "$ICON_DIR/WhiteSur-dark/apps/scalable/openhands.png" 2>/dev/null || true

    for theme in hicolor WhiteSur WhiteSur-dark; do
        cache="$ICON_DIR/$theme"
        [[ -d "$cache" ]] && gtk-update-icon-cache -f "$cache" 2>/dev/null || true
    done
}

# ---------------------------------------------------------------------------
# 2. Power management
# ---------------------------------------------------------------------------
configure_power() {
    log "Configuring power management (display always on) ..."
    cat > "$HOME_DIR/.config/powermanagementprofilesrc" <<'EOF'
[Migration]
MigratedProfilesToPlasma6=powerdevilrc

[AC][Display]
DimDisplay=false
DimDisplayIdleTimeoutSec=-1
TurnOffDisplayIdleTimeoutSec=0
TurnOffDisplayWhenIdle=false

[AC][IdleHandler]
IdleAction=0
IdleActionIdleTimeoutSec=-1

[AC][SuspendSession]
AutoSuspendAction=0
AutoSuspendIdleTimeoutSec=-1

[Battery][Display]
DimDisplay=false
DimDisplayIdleTimeoutSec=-1
TurnOffDisplayIdleTimeoutSec=0
TurnOffDisplayWhenIdle=false

[Battery][IdleHandler]
IdleAction=0
IdleActionIdleTimeoutSec=-1

[Battery][SuspendSession]
AutoSuspendAction=0
AutoSuspendIdleTimeoutSec=-1

[LowBattery][Display]
DimDisplay=false
DimDisplayIdleTimeoutSec=-1
TurnOffDisplayIdleTimeoutSec=0
TurnOffDisplayWhenIdle=false

[LowBattery][IdleHandler]
IdleAction=0
IdleActionIdleTimeoutSec=-1

[LowBattery][SuspendSession]
AutoSuspendAction=0
AutoSuspendIdleTimeoutSec=-1
EOF
}

# ---------------------------------------------------------------------------
# 3. Panel background: force WhiteSur panel SVGs to true black
# ---------------------------------------------------------------------------
configure_panel_black() {
    log "Patching WhiteSur panel background to true black ..."
    local theme_dir="$HOME_DIR/.local/share/plasma/desktoptheme/WhiteSur-dark"
    [[ -d "$theme_dir" ]] || return 0

    for variant in opaque solid translucent widgets; do
        local src="$theme_dir/$variant/widgets/panel-background.svgz"
        [[ -f "$src" ]] || continue
        local tmp
        tmp=$(mktemp)
        zcat "$src" > "$tmp"
        sed -i \
            -e 's/#333333/#000000/g; s/#1a1a1a/#000000/g; s/#2d2d2d/#000000/g; s/#3c3c3c/#000000/g; s/#424242/#000000/g; s/#4a4a4a/#000000/g' \
            -e 's/opacity:0\.9/opacity:1/g; s/opacity:0\.66663194/opacity:1/g; s/opacity:0\.45/opacity:1/g; s/opacity:0\.25/opacity:1/g' \
            -e 's/fill:#f5f5f5/fill:#000000/g; s/fill:#ffffff/fill:#000000/g; s/fill:currentColor/fill:#000000/g' \
            -e 's/thick-hint-top-margin" width="8"/thick-hint-top-margin" width="2"/g; s/thick-hint-bottom-margin" width="8"/thick-hint-bottom-margin" width="2"/g; s/thick-hint-left-margin" width="8"/thick-hint-left-margin" width="2"/g; s/thick-hint-right-margin" width="8"/thick-hint-right-margin" width="2"/g' \
            -e 's/thick-hint-top-margin" height="8"/thick-hint-top-margin" height="2"/g; s/thick-hint-bottom-margin" height="8"/thick-hint-bottom-margin" height="2"/g; s/thick-hint-left-margin" height="8"/thick-hint-left-margin" height="2"/g; s/thick-hint-right-margin" height="8"/thick-hint-right-margin" height="2"/g' \
            "$tmp"
        gzip -c "$tmp" > "$src"
        rm "$tmp"
    done

    local tasks_svg="$theme_dir/widgets/tasks.svgz"
    if [[ -f "$tasks_svg" ]]; then
        tmp=$(mktemp)
        zcat "$tasks_svg" > "$tmp"
        sed -i \
            -e 's/normal-hint-top-margin" width="4"/normal-hint-top-margin" width="1"/g; s/normal-hint-bottom-margin" width="2"/normal-hint-bottom-margin" width="1"/g; s/normal-hint-left-margin" width="4"/normal-hint-left-margin" width="1"/g; s/normal-hint-right-margin" width="2"/normal-hint-right-margin" width="1"/g' \
            -e 's/normal-hint-top-margin" height="2"/normal-hint-top-margin" height="1"/g; s/normal-hint-bottom-margin" height="4"/normal-hint-bottom-margin" height="1"/g; s/normal-hint-left-margin" height="2"/normal-hint-left-margin" height="1"/g; s/normal-hint-right-margin" height="4"/normal-hint-right-margin" height="1"/g' \
            "$tmp"
        gzip -c "$tmp" > "$tasks_svg"
        rm "$tmp"
    fi

    local deco_svg="$HOME_DIR/.local/share/aurorae/themes/WhiteSur-dark/decoration.svg"
    if [[ -f "$deco_svg" ]]; then
        sed -i \
            -e 's/#363636/#000000/g; s/#2d2d2d/#000000/g; s/#242424/#000000/g; s/#1a1a1a/#000000/g' \
            "$deco_svg"
    fi

    local plasmashellrc="$HOME_DIR/.config/plasmashellrc"
    if [[ -f "$plasmashellrc" ]]; then
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $TOP_CONTAINMENT" --key "panelOpacity" "1"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $TOP_CONTAINMENT" --key "floating" "1"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $TOP_CONTAINMENT" --group "Defaults" --key "thickness" "$TOP_THICKNESS"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $TOP_CONTAINMENT" --group "Defaults" --key "maxLength" "3840"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $TOP_CONTAINMENT" --group "Defaults" --key "minLength" "0"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $DOCK_CONTAINMENT" --key "panelOpacity" "1"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $DOCK_CONTAINMENT" --key "floating" "1"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $DOCK_CONTAINMENT" --group "Defaults" --key "thickness" "$DOCK_THICKNESS"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $DOCK_CONTAINMENT" --group "Defaults" --key "maxLength" "3840"
        kwriteconfig6 --file "$plasmashellrc" --group "PlasmaViews" --group "Panel $DOCK_CONTAINMENT" --group "Defaults" --key "minLength" "0"
        python3 - "$plasmashellrc" <<'PY'
import re, sys
path = sys.argv[1]
with open(path) as f: txt = f.read()
out = []
skip = False
for line in txt.splitlines(keepends=True):
    if re.match(r'^\[PlasmaViews\]\[Panel \d+\]\[Horizontal\d+\]', line):
        skip = True
        continue
    if skip and line.startswith('['):
        skip = False
    if not skip:
        out.append(line)
with open(path, 'w') as f: f.writelines(out)
PY
    fi
}

# ---------------------------------------------------------------------------
# 4. Wallpapers
# ---------------------------------------------------------------------------
build_video_urls() {
    python3 - "$WALLDIR" <<'PY'
import json, os, sys
base = sys.argv[1]
paths = []
for f in sorted(os.listdir(base)):
    if f.lower().endswith('.mp4'):
        paths.append(os.path.join(base, f))
print(json.dumps([{"filename": f"file://{p}", "enabled": True, "duration": 0, "customDuration": 0, "playbackRate": 1.0, "alternativePlaybackRate": 0.01, "loop": True} for p in paths]))
PY
}

configure_wallpaper() {
    log "Configuring Smart Video Wallpaper ..."
    local urls
    urls="$(build_video_urls)"

    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "PlaybackRate" "0.35"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "ChangeWallpaperMode" "1"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "RandomMode" "false"
    # Crossfade disabled: two 4K players can exceed Qt Multimedia's buffer.
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "CrossfadeEnabled" "false"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "ResumeLastVideo" "false"
    if [[ -f "$WALLDIR/02-oled-corner-glows.mp4" ]]; then
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "LastVideo" "file:///var/home/agent-42/Videos/RGB-Wallpapers/02-oled-corner-glows.mp4"
    fi
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "ChangeWallpaperTimerHours" "0"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "ChangeWallpaperTimerMinutes" "15"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "ChangeWallpaperTimerSeconds" "0"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$WALL_CONTAINMENT" --group "Wallpaper" --group "luisbocanegra.smart.video.wallpaper.reborn" --group "General" --key "VideoUrls" "$urls"
}

# ---------------------------------------------------------------------------
# 5. macOS-style .desktop overrides
# ---------------------------------------------------------------------------
write_desktop_overrides() {
    log "Writing macOS-style desktop overrides ..."

    cat > "$DESKTOP_DIR/org.kde.dolphin.desktop" <<'EOF'
[Desktop Entry]
Name=Finder
Exec=dolphin %u
Icon=org.kde.dolphin
GenericName=File Manager
Type=Application
Categories=Qt;KDE;System;FileTools;FileManager;
StartupWMClass=dolphin
EOF

    cat > "$DESKTOP_DIR/org.kde.konsole.desktop" <<'EOF'
[Desktop Entry]
Name=Terminal
Comment=Command line access
Exec=konsole --profile "macOS Terminal"
Icon=utilities-terminal
Type=Application
Categories=Qt;KDE;System;TerminalEmulator;
StartupWMClass=konsole
StartupNotify=false
EOF

    cat > "$DESKTOP_DIR/org.kde.kwrite.desktop" <<'EOF'
[Desktop Entry]
Name=TextEdit
Comment=Text editor
Exec=kwrite %U
Icon=text-editor
Type=Application
Categories=Qt;KDE;Utility;TextEditor;
StartupWMClass=kwrite
EOF

    cat > "$DESKTOP_DIR/systemsettings.desktop" <<'EOF'
[Desktop Entry]
Name=Settings
Comment=Configure the system's behavior and appearance
Exec=env LD_PRELOAD= systemsettings
Icon=preferences-system
Type=Application
Categories=Qt;KDE;Settings;
StartupWMClass=systemsettings5
EOF

    cat > "$DESKTOP_DIR/trivalent.desktop" <<'EOF'
[Desktop Entry]
Name=Safari
Comment=A security-focused browser themed like macOS Safari
Exec=/usr/bin/trivalent --profile-directory=Default --ozone-platform=wayland --enable-features=UseOzonePlatform --disable-features=WaylandWindowDecorations %U
Icon=safari-dark
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
StartupWMClass=trivalent
EOF

    cat > "$DESKTOP_DIR/org.kde.spectacle.desktop" <<'EOF'
[Desktop Entry]
Name=Screenshot
Comment=Take screenshots and screen recordings
Exec=/usr/bin/spectacle
Icon=spectacle
Type=Application
Categories=Qt;KDE;Utility;
StartupWMClass=spectacle
DBusActivatable=true
X-KDE-Wayland-Interfaces=org_kde_plasma_window_management,zkde_screencast_unstable_v1
X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2
EOF

    cat > "$DESKTOP_DIR/openwebui.desktop" <<'EOF'
[Desktop Entry]
Name=Dolphin3 Canvas
Comment=Local Dolphin 3.0 LLM chat (offline via Ollama, no API key required)
Exec=bash -c 'systemctl --user start open-webui.service && sleep 5 && xdg-open http://localhost:60808'
Type=Application
Icon=dolphin3
Terminal=false
Categories=Utility;Network;
StartupNotify=true
StartupWMClass=open-webui
EOF

    cat > "$DESKTOP_DIR/openhands.desktop" <<'EOF'
[Desktop Entry]
Name=OpenHands
Comment=AI coding agent
Exec=bash -c 'systemctl --user start openhands.service && sleep 6 && xdg-open http://localhost:60300'
Type=Application
Icon=openhands
Terminal=false
Categories=Development;
StartupNotify=true
StartupWMClass=openhands
EOF

    cat > "$DESKTOP_DIR/trash.desktop" <<'EOF'
[Desktop Entry]
Name=Trash
Comment=Open the Trash folder
Exec=dolphin trash:/
Icon=user-trash
Type=Application
Categories=Qt;KDE;System;FileTools;FileManager;
StartupNotify=true
StartupWMClass=dolphin
Terminal=false
EOF
}

# ---------------------------------------------------------------------------
# 6. Konsole profile
# ---------------------------------------------------------------------------
setup_konsole() {
    log "Creating macOS Terminal Konsole profile ..."

    cat > "$KONSOLE_DIR/macOS Terminal.profile" <<'EOF'
[Appearance]
ColorScheme=macOS Terminal
Font=Noto Sans Mono,12,-1,5,50,0,0,0,0,0

[General]
Name=macOS Terminal
Parent=FALLBACK/
ShowMenuBarByDefault=false
TabBarMode=2
EOF

    cat > "$KONSOLE_DIR/macOS Terminal.colorscheme" <<'EOF'
[Background]
Color=0,0,0

[BackgroundIntense]
Color=0,0,0

[Color0]
Color=0,0,0

[Color0Intense]
Color=104,104,104

[Color1]
Color=255,84,84

[Color1Intense]
Color=255,120,120

[Color2]
Color=36,161,67

[Color2Intense]
Color=86,255,101

[Color3]
Color=255,252,103

[Color3Intense]
Color=255,255,160

[Color4]
Color=74,144,226

[Color4Intense]
Color=120,171,255

[Color5]
Color=170,74,199

[Color5Intense]
Color=220,101,255

[Color6]
Color=50,175,178

[Color6Intense]
Color=103,255,255

[Color7]
Color=201,201,201

[Color7Intense]
Color=255,255,255

[Foreground]
Color=235,235,235

[ForegroundIntense]
Color=255,255,255

[General]
Description=macOS Terminal
Opacity=1
EOF

    kwriteconfig6 --file "$HOME_DIR/.config/konsolerc" --group "Desktop Entry" --key "DefaultProfile" "macOS Terminal.profile"
    kwriteconfig6 --file "$HOME_DIR/.config/konsolerc" --group "MainWindow" --key "MenuBar" "Disabled"
}

# ---------------------------------------------------------------------------
# 7. Dock
# ---------------------------------------------------------------------------
configure_dock() {
    log "Configuring dock ..."
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "alignment" "center"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "floating" "true"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "lengthMode" "2"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "thickness" "$DOCK_THICKNESS"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "offset" "0"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "panelVisibility" "0"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "opacity" "opaque"

    if [ -n "$DOCK_APPLET" ]; then
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "General" --key "AppletOrder" "$DOCK_APPLET"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "launchers" \
            'applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kwrite.desktop,applications:systemsettings.desktop,applications:trivalent.desktop,applications:org.kde.spectacle.desktop,applications:openwebui.desktop,applications:openhands.desktop,applications:trash.desktop'
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "separateLaunchers" "false"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "launchInPlace" "true"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "sortingStrategy" "0"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "groupingStrategy" "0"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "iconSize" "$DOCK_ICON_SIZE"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "iconSpacing" "0"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$DOCK_CONTAINMENT" --group "Applets" --group "$DOCK_APPLET" --group "Configuration" --group "General" --key "fill" "false"
    else
        log "WARNING: dock icon-tasks applet not discovered; skipping dock AppletOrder/launcher config"
    fi

    kwriteconfig6 --file "$KLAUNCH_RC" --group "BusyCursorSettings" --key "Blinking" "false"
    kwriteconfig6 --file "$KLAUNCH_RC" --group "BusyCursorSettings" --key "Bouncing" "false"
    kwriteconfig6 --file "$KLAUNCH_RC" --group "BusyCursorSettings" --key "Timeout" "1"
    kwriteconfig6 --file "$KLAUNCH_RC" --group "FeedbackStyle" --key "BusyCursor" "false"
    kwriteconfig6 --file "$KLAUNCH_RC" --group "FeedbackStyle" --key "TaskbarButton" "true"
    kwriteconfig6 --file "$KLAUNCH_RC" --group "TaskbarButtonSettings" --key "Timeout" "2"
}

# ---------------------------------------------------------------------------
# 8. Top panel
# ---------------------------------------------------------------------------
configure_top_panel() {
    log "Configuring top panel ..."
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "General" --key "thickness" "$TOP_THICKNESS"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "General" --key "floating" "true"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "General" --key "offset" "0"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "General" --key "alignment" "left"
    kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "General" --key "opacity" "opaque"

    if [ -z "$KICKOFF_APPLET" ]; then
        log "WARNING: kickoff applet not discovered; skipping kickoff config"
    else
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$KICKOFF_APPLET" --group "Configuration" --group "General" --key "icon" "start-here"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$KICKOFF_APPLET" --group "Configuration" --group "General" --key "favoritesPortedToKAstats" "true"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$KICKOFF_APPLET" --group "Configuration" --group "General" --key "systemApplications" "systemsettings.desktop\\,org.kde.kinfocenter.desktop"
    fi

    if [ -z "$APPMENU_APPLET" ]; then
        log "WARNING: appmenu applet not discovered; skipping appmenu config"
    else
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$APPMENU_APPLET" --group "Configuration" --group "General" --key "compactView" "true"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$APPMENU_APPLET" --group "Configuration" --group "General" --key "showIcon" "false"
    fi

    if [ -x "$HOME_DIR/.local/bin/macos-systemtray.py" ]; then
        python3 "$HOME_DIR/.local/bin/macos-systemtray.py" --restart
    fi

    if [ -z "$SYSTRAY_APPLET" ]; then
        log "WARNING: system tray applet not discovered; skipping tray shownItems config"
    else
        local essential
        essential='org.kde.plasma.volume,org.kde.plasma.networkmanagement,org.kde.plasma.battery,org.kde.plasma.notifications,org.kde.plasma.clipboard'
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "shownItems" "$essential"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "extraItems" "$essential"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "knownItems" "$essential"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "iconSpacing" "1"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "iconSize" "$SYSTRAY_ICON_SIZE"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$SYSTRAY_APPLET" --group "General" --key "scaleIconsToFit" "true"
    fi

    if [ -z "$CLOCK_APPLET" ]; then
        log "WARNING: digital clock applet not discovered; skipping clock config"
    else
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$CLOCK_APPLET" --group "Configuration" --group "Appearance" --key "showDate" "true"
        kwriteconfig6 --file "$PLASMA_RC" --group "Containments" --group "$TOP_CONTAINMENT" --group "Applets" --group "$CLOCK_APPLET" --group "Configuration" --group "Appearance" --key "use24hFormat" "0"
    fi
}

# ---------------------------------------------------------------------------
# 9. Theme globals
# ---------------------------------------------------------------------------
configure_theme_globals() {
    log "Applying theme globals ..."
    kwriteconfig6 --file kdeglobals --group General --key widgetStyle kvantum
    kwriteconfig6 --file kdeglobals --group General --key Name WhiteSurDark
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme WhiteSurDark
    kwriteconfig6 --file kdeglobals --group General --key Theme WhiteSur-dark
    kwriteconfig6 --file kdeglobals --group Icons --key Theme WhiteSur-dark
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum

    mkdir -p "$HOME_DIR/.config/Kvantum"
    kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme WhiteSur-Dark

    mkdir -p "$HOME_DIR/.config/gtk-3.0" "$HOME_DIR/.config/gtk-4.0"
    cat > "$HOME_DIR/.config/gtk-3.0/settings.ini" <<EOT
[Settings]
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
gtk-cursor-theme-name=WhiteSur-cursors
gtk-font-name=Inter 10
gtk-application-prefer-dark-theme=1
EOT
    cp "$HOME_DIR/.config/gtk-3.0/settings.ini" "$HOME_DIR/.config/gtk-4.0/settings.ini"

    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__WhiteSur-dark
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize None
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key font "Inter,10,-1,0,400,0,0,0,0,0"
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true

    kwriteconfig6 --file kwinrc --group Windows --key Placement Centered
    kwriteconfig6 --file kwinrc --group Windows --key ElectricBorders 0
    kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta "org.kde.krunner,/App,,KRunner"

    python3 - "$HOME_DIR/.config/kwinrc" <<'PY'
import sys, re
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out = []
skip = False
for line in lines:
    if line.startswith("[Tiling"):
        skip = True
        continue
    if skip and line.startswith("["):
        skip = False
    if not skip:
        out.append(line)
with open(path, "w") as f:
    f.writelines(out)
PY
}

# ---------------------------------------------------------------------------
# 10. Window decorations
# ---------------------------------------------------------------------------
configure_aurorae() {
    if [[ -f "$AURORAE" ]]; then
        log "Tightening WhiteSur-dark title bar ..."
        python3 - "$AURORAE" <<'AURPY'
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str
cp.read(path)
if 'Layout' not in cp.sections():
    cp.add_section('Layout')
for k, v in {
    'PaddingTop': '16', 'PaddingBottom': '14',
    'PaddingLeft': '14', 'PaddingRight': '14',
    'TitleEdgeTop': '4', 'TitleEdgeBottom': '4',
    'TitleEdgeLeft': '6', 'TitleEdgeRight': '6',
    'TitleBorderLeft': '62', 'TitleBorderRight': '62',
    'ButtonSpacing': '8',
    'TitleEdgeTopMaximized': '4', 'TitleEdgeBottomMaximized': '4',
    'TitleEdgeLeftMaximized': '6', 'TitleEdgeRightMaximized': '6',
}.items():
    cp.set('Layout', k, v)
with open(path, 'w') as f:
    cp.write(f)
AURPY
    fi
}

# ---------------------------------------------------------------------------
# 11. Web services
# ---------------------------------------------------------------------------
setup_web_services() {
    log "Setting up OpenWebUI / OpenHands services ..."

    cat > "$BIN_DIR/openwebui-start.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
if ! systemctl --user is-active --quiet ollama.service 2>/dev/null; then
    echo "WARNING: Ollama service is not running. Start it with: systemctl --user start ollama.service"
fi
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
export OPENAI_API_BASE_URL="${OPENAI_API_BASE_URL:-http://127.0.0.1:11434/v1}"
export ENABLE_OPENAI_API="${ENABLE_OPENAI_API:-false}"
export PORT="${PORT:-60808}"
export HOST="${HOST:-0.0.0.0}"
exec "$HOME/.local/venvs/open-webui/bin/open-webui" serve --host "$HOST" --port "$PORT"
EOF
    chmod +x "$BIN_DIR/openwebui-start.sh"

    cat > "$BIN_DIR/openhands-start.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
export LLM_API_KEY="${LLM_API_KEY:-ollama}"
export LLM_BASE_URL="${LLM_BASE_URL:-http://127.0.0.1:11434}"
export LLM_MODEL="${LLM_MODEL:-ollama/Dolphin3.0-Llama3.2-8B}"
export WORKSPACE_BASE="${WORKSPACE_BASE:-$HOME/workspace}"
export OPENHANDS_SUPPRESS_BANNER=1
export port="${port:-60300}"
mkdir -p "$WORKSPACE_BASE"
exec "$HOME/.local/venvs/openhands-server/bin/uvicorn" openhands.app_server.app:app --host 0.0.0.0 --port "$port"
EOF
    chmod +x "$BIN_DIR/openhands-start.sh"

    cat > "$SERVICE_DIR/open-webui.service" <<EOF
[Unit]
Description=OpenWebUI Dolphin3 Canvas
After=network-online.target ollama.service
Wants=ollama.service

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=%h/.local/bin/openwebui-start.sh
Environment="PATH=%h/.local/venvs/open-webui/bin:/usr/bin:/bin:%h/.local/bin"
Environment="OLLAMA_BASE_URL=http://127.0.0.1:11434"
Environment="ENABLE_OPENAI_API=false"

[Install]
WantedBy=default.target
EOF

    cat > "$SERVICE_DIR/openhands.service" <<EOF
[Unit]
Description=OpenHands AI coding agent
After=network-online.target ollama.service
Wants=ollama.service

[Service]
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=%h/.local/src/OpenHands
ExecStart=%h/.local/bin/openhands-start.sh
Environment="PATH=%h/.local/venvs/openhands-server/bin:/home/linuxbrew/.linuxbrew/bin:/usr/bin:/bin:%h/.local/bin"
Environment="OPENHANDS_SUPPRESS_BANNER=1"
Environment="SERVE_FRONTEND=true"
Environment="LLM_MODEL=ollama/Dolphin3.0-Llama3.2-8B"

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now open-webui.service openhands.service || true
    log "OpenWebUI should be on http://localhost:60808 and OpenHands on http://localhost:60300"
}

# ---------------------------------------------------------------------------
# 12. Dolphin
# ---------------------------------------------------------------------------
configure_dolphin() {
    log "Configuring Dolphin to look like macOS Finder ..."
    local drc="$HOME_DIR/.config/dolphinrc"
    mkdir -p "$HOME_DIR/.config"
    python3 - "$drc" <<'PY'
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str
cp.read(path)
if 'General' not in cp.sections():
    cp.add_section('General')
for k, v in {
    'HomeUrl': '/home/agent-42',
    'MenuBar': 'Disabled',
    'ShowFullPath': 'false',
    'ShowStatusBar': 'false',
    'ShowZoomSlider': 'false',
    'UseTabForSwitching': 'true',
    'SingleClick': 'true',
    'NaturalSorting': 'true',
    'ShowPreview': 'true',
    'ShowHiddenFiles': 'false',
    'SortDirectoriesFirst': 'true',
    'ViewMode': '0',
}.items():
    cp.set('General', k, v)
if 'Icon View' not in cp.sections():
    cp.add_section('Icon View')
for k, v in {'IconSize': '64', 'PreviewSize': '64', 'TextWidthIndex': '2', 'ArrangeItems': '1'}.items():
    cp.set('Icon View', k, v)
if 'KFileDialog Settings' not in cp.sections():
    cp.add_section('KFileDialog Settings')
cp.set('KFileDialog Settings', 'Places Icons Auto-resize', 'false')
cp.set('KFileDialog Settings', 'Places Icons Static Size', '22')
if 'MainWindow' not in cp.sections():
    cp.add_section('MainWindow')
cp.set('MainWindow', 'MenuBar', 'Disabled')
with open(path, 'w') as f:
    cp.write(f)
PY
    kwriteconfig6 --file systemsettingsrc --group MainWindow --key MenuBar Disabled
}

# ---------------------------------------------------------------------------
# 13. Transparency + blur
# ---------------------------------------------------------------------------
configure_transparency() {
    log "Applying transparency and blur ..."
    if [ -x "$HOME_DIR/.local/bin/tahoe-transparency.sh" ]; then
        "$HOME_DIR/.local/bin/tahoe-transparency.sh"
    else
        log "WARNING: tahoe-transparency.sh not found; skipping transparency pass"
    fi
}

# ---------------------------------------------------------------------------
# 14. Restart Plasma
# ---------------------------------------------------------------------------
restart_plasma() {
    log "Restarting Plasma Shell ..."
    if pgrep -x plasmashell >/dev/null 2>&1; then
        killall plasmashell 2>/dev/null || true
        sleep 2
        kstart6 plasmashell >/dev/null 2>&1 || true
    else
        log "plasmashell not running; changes apply on next login."
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "Starting macOS Tahoe replica runbook ..."
    configure_power
    configure_theme_globals
    configure_panel_black
    setup_icons
    if [ -x "$BIN_DIR/tahoe-wallpaper-helper.sh" ]; then
        "$BIN_DIR/tahoe-wallpaper-helper.sh" "$WALLDIR"
    else
        log "WARNING: tahoe-wallpaper-helper.sh not found; skipping OLED wallpaper generation"
    fi
    configure_wallpaper
    write_desktop_overrides
    setup_konsole
    configure_dock
    configure_top_panel
    configure_aurorae
    configure_dolphin
    setup_web_services
    configure_transparency
    restart_plasma
    log "Done. If the wallpaper is black, open Desktop Wallpaper settings and re-select Smart Video Wallpaper Reborn."
}

main "$@"
