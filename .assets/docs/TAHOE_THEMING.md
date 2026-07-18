# macOS Tahoe-inspired KDE Theming

This image ships a macOS Tahoe-style look for KDE Plasma 6 on SecureBlue:

- **Top panel:** true-black 26 px floating menu bar, left-aligned, Apple logo, global menu, minimal system tray, 12-hour clock.
- **Bottom dock:** true-black 50 px floating centered dock, 48 px icons, always visible.
- **Window decorations:** WhiteSur-dark Aurorae with left-side stoplights (`XIA`), x1.25 size variant for HiDPI correctness.
- **Application style:** Kvantum (`WhiteSur-Dark`) with compositing disabled to avoid the Kvantum 1.1.7 / Qt 6.11+ crash.
- **Icons:** `WhiteSur-dark` icon theme and `WhiteSur-cursors`.
- **Font:** Inter (via `rsms-inter-fonts`).
- **Wallpaper:** dark OLED-friendly static gradient shipped in `/usr/share/tahoe/wallpapers/default.png`.

## How it works

1. **Build-time** — `modules/tahoe-theming/install-tahoe-themes.sh` downloads and installs WhiteSur assets system-wide, patches panel/decoration SVGs to true black, sets the x1.25 Aurorae variant, and copies static XDG defaults to `/usr/etc/xdg`.
2. **First-login** — `tahoe-cosmetic-reset.service` (a user service ordered `Before=plasma-plasmashell.service`) writes the Plasma panel/dock layout, renamed `.desktop` entries (Finder, Terminal, Safari, etc.), and user icons. It leaves a stamp at `~/.local/share/tahoe-cosmetic-reset-done` so installed systems only run it once. On live USB the stamp is lost each reboot, so the theme is restored every fresh session.

## Key files

| Path | Purpose |
|------|---------|
| `/usr/bin/tahoe-cosmetic-reset` | First-login cosmetic reset script |
| `/usr/lib/systemd/user/tahoe-cosmetic-reset.service` | User service that runs before Plasma |
| `/usr/etc/xdg/kdeglobals` | Theme, icon, font, and L&F defaults |
| `/usr/etc/xdg/kwinrc` | Aurorae theme, left stoplights, centered placement |
| `/usr/etc/xdg/plasmarc` | Plasma theme name |
| `/usr/etc/xdg/plasmashellrc` | Panel opacity / floating hints |
| `/usr/etc/xdg/dolphinrc` | Finder-style Dolphin settings |
| `/usr/etc/xdg/konsolerc` + `konsole/macOS Terminal.*` | True-black Terminal profile |
| `/usr/share/tahoe/wallpapers/default.png` | Default OLED-friendly wallpaper |
| `/usr/share/tahoe/icons/{start-here,safari-dark}.svg` | Apple logo and Safari-style icon |
| `/usr/bin/tahoe-gap-optimizer` | Optional runtime helper that tightens panel/dock spacing and patches Aurorae geometry |

## Runtime tools

After first login you can further tighten spacing with the optional helper:

```bash
tahoe-gap-optimizer
```

This adjusts the current user's panel/dock dimensions, system-tray spacing, Aurorae title-bar geometry, and patches the persistence helpers (`cosmetic-reset`, `macos-systemtray`, `macos-tahoe-runbook`) so the changes survive the next login. It is idempotent and backs up edited files to `~/.config/backup/tahoe-gap-optimizer-<timestamp>/`.

## macOS icon scraper

The build can replace a few application icons with authentic macOS-style artwork from `macosicons.com`. Because the API requires an API key, scraping is disabled by default and the image falls back to bundled WhiteSur icons plus deterministic SVG fallbacks for Microsoft Word, Photos, and Netflix.

To enable live scraping in CI, add a repository secret:

1. Go to **Settings → Secrets and variables → Actions → New repository secret**.
2. Name: `MACOS_ICONS_API_KEY`
3. Value: your `macosicons.com` API key.

The workflow passes it to `scrape-macos-icons.sh`; without it the script exits cleanly and the build continues.

## Customization

- **Scale:** Plasma global scale multiplies panel/dock dimensions automatically. The Aurorae x1.25 variant is preselected to keep stoplights from collapsing on HiDPI displays.
- **Translucency:** `composite=false` is the default in `/usr/etc/xdg/Kvantum/kvantum.kvconfig` for stability. Re-enable it in Kvantum Manager once the upstream Kvantum/Qt compositing crash is resolved.
- **Wallpaper:** replace `/usr/share/tahoe/wallpapers/default.png` or set a different image in System Settings → Wallpaper after login.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| Top panel is gray | `tahoe-cosmetic-reset` patches panel SVGs at image build time; run it manually with `systemctl --user restart tahoe-cosmetic-reset.service` if they revert. |
| Trivalent has no stoplights | Confirm it launches via the overridden `.desktop` with `--ozone-platform=wayland --disable-features=WaylandWindowDecorations`. |
| Stoplights are tiny | The x1.25 Aurorae variant is selected in `/usr/etc/xdg/kwinrc` (`WhiteSur-dark_x1.25`). |
| Theme resets after manual tweak | `tahoe-cosmetic-reset.service` only runs once on installed systems. Delete `~/.local/share/tahoe-cosmetic-reset-done` and re-login to re-apply. |
