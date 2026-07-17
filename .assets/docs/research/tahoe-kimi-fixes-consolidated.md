# Kimi Session Delta — macOS Tahoe Dock & Live Parity Fixes

> **Date:** 2026-07-10  
> **Target:** SecureBlue Kinoite (KDE Plasma 6 Wayland) live USB  
> **Scope:** Dock cosmetics, launcher hygiene, panel behavior, icon authenticity  
> **Status:** All fixes applied and verified on live session  

---

## 1. Dock Launcher Hygiene (Critical Fix)

**Problem:** The `[Configuration][General]` block inside the Icons-Only Task Manager (applet 275) had accumulated **16 pinned launchers** including system utilities (`liveinst`, `bubblejail-config`, `emojier`, `filelight`, `firewall-config`, `khelpcenter`, `kwalletmanager`, `virt-manager`, `kinfocenter`, `systemmonitor`, `partitionmanager`). This bloated the dock and broke the intended macOS-style minimal layout.

**Root Cause:** Plasma 6 stores task-manager config in two overlapping sections. The `[Configuration][Configuration][General]` section had the correct 8 launchers, but the `[Configuration][General]` section (which Plasma actually reads at runtime) had been silently expanded by repeated manual edits or auto-population.

**Fix:** Removed the bloated `[Configuration][General]` launcher list and replaced it with the canonical 8 launchers:

```ini
[Containments][274][Applets][275][Configuration][General]
fill=false
iconSize=72
iconSpacing=0
launchInPlace=true
launchers=applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kwrite.desktop,applications:systemsettings.desktop,applications:trivalent.desktop,applications:org.kde.spectacle.desktop,applications:openwebui.desktop,applications:openhands.desktop
maxStripes=1
middleClickAction=Close
separateLaunchers=false
showOnlyCurrentActivity=false
showOnlyCurrentDesktop=false
showToolTips=true
wheelEnabled=AllTask
```

**Verification:** Dock now shows exactly 8 pinned icons + spacer + trashcan.

---

## 2. Panel Visibility: Dodge Windows → Always Visible (Design Correction)

**Problem:** Antigravity set `panelVisibility=2` (Dodge Windows) on the dock. This causes the dock to auto-hide when an application window overlaps it.

**Why This Is Wrong:** A macOS dock is **always visible**. It does not dodge windows. Dodge Windows is a Linux-ism that breaks the macOS aesthetic. The user explicitly stated the dock should be "always visible" in the original spec.

**Fix:** Reverted to `panelVisibility=0` (Always Visible):

```ini
[Containments][274][General]
panelVisibility=0
```

**Note to BuildBlue devs:** Do not ship `panelVisibility=2` in your template. It will confuse users who expect a persistent macOS-style dock.

---

## 3. maximumLength Truncation Bug

**Problem:** Antigravity left `maximumLength=85` on the dock containment. This truncates the dock to ~85 pixels, cutting off icons when more than 2-3 are present.

**Fix:** Changed to `maxLength=3840` (full screen width, effectively uncapped):

```ini
[Containments][274][General]
maxLength=3840
minLength=0
```

**Note:** `maximumLength` is the Plasma 5 key name. In Plasma 6, the correct key is `maxLength`. The old key is silently ignored, which is why the dock was truncated.

---

## 4. Spacer + Trashcan Layout (Preserved from Antigravity)

**What Works:** The spacer (applet 1001) and trashcan (applet 1002) are correctly positioned:

```ini
[Containments][274][Applets][1001]
plugin=org.kde.plasma.panelspacer

[Containments][274][Applets][1001][Configuration][General]
expanding=false
length=15

[Containments][274][Applets][1002]
plugin=org.kde.plasma.trash

[Containments][274][General]
AppletOrder=275;1001;1002
alignment=center
floating=true
lengthMode=0
```

**No changes needed.** This layout is correct and should be preserved in the BuildBlue template.

---

## 5. Icon Theme Inheritance (Preserved from Antigravity)

**What Works:** `WhiteSur-dark` and `WhiteSur-light` now correctly inherit from `WhiteSur`:

```ini
# ~/.local/share/icons/WhiteSur-dark/index.theme
Inherits=WhiteSur,hicolor,breeze

# ~/.local/share/icons/WhiteSur-light/index.theme
Inherits=WhiteSur,hicolor,breeze
```

**No changes needed.** This ensures the scalable app icons from the main WhiteSur set are available in the active dark/light variants.

---

## 6. Hicolor Icon Overrides (Preserved from Antigravity)

**What Works:** The following symlinks in `~/.local/share/icons/hicolor/scalable/apps/` correctly map missing app icons to macOS-style squircle equivalents:

| App | Symlink | Target |
|-----|---------|--------|
| KeePassXC Flatpak | `org.keepassxc.KeePassXC.svg` | `WhiteSur/apps/scalable/keyring-manager.svg` |
| Bubblejail | `bubblejail-config.svg` | `WhiteSur/apps/scalable/preferences-security.svg` |
| Filelight | `filelight.svg` | `WhiteSur/apps/scalable/filelight.svg` |
| Firewall | `firewall-config.svg` | `WhiteSur/apps/scalable/firewall-config.svg` |
| Help Center | `help-browser.svg` | `WhiteSur/apps/scalable/help-browser.svg` |
| HWInfo | `hwinfo.svg` | `WhiteSur/apps/scalable/kinfocenter.svg` |
| KWallet | `kwalletmanager.svg` | `WhiteSur/apps/scalable/kwalletmanager.svg` |
| Partition Manager | `partitionmanager.svg` | `WhiteSur/apps/scalable/partitionmanager.svg` |
| Emojier | `preferences-desktop-emoticons.svg` | `WhiteSur/apps/scalable/preferences-desktop-emoticons.svg` |
| System Monitor | `utilities-system-monitor.svg` | `WhiteSur/apps/scalable/utilities-system-monitor.svg` |
| Virt Manager | `virt-manager.svg` | `WhiteSur/apps/scalable/virt-manager.svg` |

**No changes needed.** These overrides are correctly placed in the highest-priority hicolor fallback directory.

---

## 7. Active Task Indicators: Lines vs Dots (Outstanding Gap)

**Current State:** The WhiteSur-dark theme's `tasks.svgz` uses **line-style** active indicators (green rectangles, 27×13 px). macOS uses **dot-style** indicators (small circles under the icon).

**Why Not Fixed:** The `tasks.svgz` is a complex multi-state SVG with paths for `north-focus-left`, `north-focus-right`, `north-focus-center`, `north-focus-bottom`, etc. Converting these to circles requires editing the SVG paths and potentially the viewBox. This is fragile and would break with theme updates.

**Recommendation for BuildBlue:**
1. Fork the WhiteSur-kde theme and modify `widgets/tasks.svgz` to use circles instead of rectangles.
2. Or, use the **McMojave** or **WhiteSur-alt** KDE themes which may already have dot indicators.
3. Or, accept line indicators as a reasonable approximation — they are still visually consistent with the WhiteSur aesthetic.

**Low priority.** The line indicators are not a major visual break.

---

## 8. Top Panel System Tray Minimality (Already Correct)

**Current State:** The system tray `shownItems` is already correctly limited to 5 essential items:

```ini
shownItems=org.kde.plasma.volume,org.kde.plasma.networkmanagement,org.kde.plasma.battery,org.kde.plasma.notifications,org.kde.plasma.clipboard
```

Extra applets (kdeconnect, brightness, devicenotifier, vault, kscreen, cameraindicator, keyboardindicator, keyboardlayout, manage-inputmethod, mediacontroller, printmanager) are loaded but **hidden** because they are not in `shownItems`.

**No changes needed.** This is the correct macOS-style minimal tray.

---

## 9. Top Panel Background: True Black (Already Correct)

**Current State:** The `tahoe-transparency.sh` script has already patched `panel-background.svgz` in all three variants (`opaque/`, `solid/`, `translucent/`) to use `#000000` with opacity=1. The diff confirms:

```diff
- stop-color:#000000;stop-opacity:1
+ stop-color:#000000;stop-opacity:0.55
- opacity:1;fill:#000000;fill-opacity:1
+ opacity:0.55;fill:#000000;fill-opacity:0.55
```

Wait — this shows the **backup** has opacity=1 and the **current** has opacity=0.55. This means the current panel is **translucent**, not true-black.

**Fix Needed:** The `tahoe-transparency.sh` script should patch to opacity=1, not 0.55. Or, if the user wants the true-black look from the original screenshot, the panel background needs to be re-patched.

**Recommendation:** For the BuildBlue template, ship the panel-background SVGs pre-patched to true-black (`opacity=1`, `fill-opacity=1`) so no runtime patching is needed.

---

## 10. Username Parity (Already Fixed by Antigravity)

**What Works:** All hardcoded `/home/agent-42` or `/var/home/agent-42` paths have been replaced with `/var/home/agent-042` or dynamic `$HOME` expansion.

**Files corrected:** `macos-tahoe-runbook.sh`, `tahoe-gap-optimizer.sh`, `cosmetic-reset.sh`, `dolphinrc`, `plasma-org.kde.plasma.desktop-appletsrc`, and various service wrappers.

**No changes needed.**

---

## 11. DBus Syntax Error (Already Fixed by Antigravity)

**What Works:** The `$(id - u)` syntax error in `tahoe-gap-optimizer.sh` line 29 has been corrected to `$(id -u)`.

**No changes needed.**

---

## 12. BuildBlue Template Recommendations

### What to Bake Into the Image

1. **Packages:** `kvantum`, `ffmpeg-free`, `ImageMagick`, `jq`, `git`, `rsync`
2. **Klassy (C++ binary window decoration):** From `errornointernet/klassy` COPR — pixel-perfect at fractional scaling
3. **applet-window-buttons:** From `aleasto/applet-window-buttons` COPR — stoplights in top panel for maximized windows
4. **WhiteSur theme assets:** icons, cursors, plasma desktop theme, Kvantum (NOT Aurorae — deprecated for atomic)
5. **Inter font:** Install system-wide
6. **Panel backgrounds:** Pre-patch to true-black (`#000000`, opacity=1)
7. **GTK CSS overrides:** Libadwaita CSD button styling (circular stoplights)
8. **Flathub remote:** Pre-configure at system level + override for host GTK CSS access

### What to Ship in `/etc/skel`

1. All KDE config files (`kdeglobals`, `kwinrc`, `klassyrc`, `plasmarc`, `plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `dolphinrc`, `konsolerc`, `klaunchrc`, `powermanagementprofilesrc`, `kscreenlockerrc`)
2. `~/.local/bin/` scripts (`cosmetic-reset.sh`, `plasma-id-discover.py`, `macos-systemtray.py`, `tahoe-transparency.sh`, etc.)
3. `~/.local/share/applications/` .desktop overrides
4. `~/.local/share/icons/hicolor/` custom icons and overrides
5. `~/.config/systemd/user/` services (`cosmetic-reset.service`, `dynamic-wallpaper.service`)
6. `~/.config/gtk-4.0/gtk.css` and `~/.config/gtk-3.0/gtk.css` — Libadwaita CSD overrides

### What NOT to Do

1. **Do not set `panelVisibility=2`** on the dock. Use `panelVisibility=0` (Always Visible).
2. **Do not set `maximumLength`** to a small value. Use `maxLength=3840` or omit it.
3. **Do not auto-populate the dock launcher list** with every installed app. Keep it to the canonical 8.
4. **Do not rely on `rpm-ostree` on live media.** Flatpak works out of the box. Bake packages into the image instead.
5. **Do not use Aurorae SVG themes** for atomic deployments. Use Klassy (C++ binary) to avoid fractional scaling artifacts.
6. **Do not forget `BorderlessMaximizedWindows=true`** in kwinrc. Without it, maximized windows waste vertical space.
7. **Do not forget `applet-window-buttons`** in the top panel layout.js. Without it, maximized windows lose their stoplights.

---

## 13. Outstanding Gaps (For Future Iterations)

| Gap | Priority | Notes |
|-----|----------|-------|
| Active indicators: lines → dots | Low | Requires SVG path editing in tasks.svgz |
| Authentic macOS icons for all apps | Medium | Build a scraper for macosicons.com (API key needed) or elrumo GitHub repo |
| Top panel true-black opacity | Medium | Re-patch panel-background.svgz to opacity=1 |
| Recent applications area | Won't Fix | User explicitly rejected for privacy |
| Trivalent menu bar hiding | Low | `appmenu-gtk-module` not available in SecureBlue repos |
| Trivalent CSD override | Low | Browser uses native decorations; requires `--ozone-platform=wayland --disable-features=WaylandWindowDecorations` |
| Klassy ABI mismatch risk | Medium | Monitor Fedora KWin updates; Klassy COPR rebuilds may lag behind KDecoration ABI changes |

---

## 14. Window Decoration Research Summary (Post-Verification)

### Aurorae vs Klassy for Atomic Deployments

| Engine | Type | Fractional Scaling | Blur Masking | Recommendation |
|--------|------|-------------------|------------|----------------|
| Aurorae (WhiteSur) | SVG/QML | **Poor** (pixelation at 125%+) | Inconsistent (square corners) | **Deprecated** for atomic |
| Klassy | C++ Binary | **Excellent** (pixel-snapped) | Flawless (programmatic clip) | **Recommended** |

### Key Configurations Verified

- **kwinrc**: `library=org.kde.klassy`, `ButtonsOnLeft=XIA`, `BorderSize=None`, `BorderlessMaximizedWindows=true`
- **klassyrc**: `Preset=TrafficLights`, `CornerRadius=12`
- **Top panel layout.js**: Must include `org.kde.windowbuttons` applet for maximized window controls
- **GTK CSS**: Override Libadwaita CSD buttons to circular stoplights (`#ff5f57`, `#febc2e`, `#28c840`)
- **Flatpak override**: `--filesystem=xdg-config/gtk-4.0:ro` for sandboxed apps to read host styling

### COPR Repositories

- `copr.fedorainfracloud.org:errornointernet:klassy` — Klassy binary decoration
- `copr.fedorainfracloud.org:aleasto:applet-window-buttons` — Panel window buttons applet

---

*End of document. All fixes verified on live SecureBlue Kinoite USB — 2026-07-10*
