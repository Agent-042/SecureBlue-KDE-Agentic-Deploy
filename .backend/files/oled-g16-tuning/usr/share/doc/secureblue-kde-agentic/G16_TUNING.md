# ASUS ROG Zephyrus G16 (Intel) Tuning Notes

This document covers hardware-specific tuning for the ASUS ROG Zephyrus G16
with Intel Core Ultra 9, NVIDIA GeForce RTX 5080, and OLED panel.

## OLED dimming and burn-in mitigation

OLED panels can suffer from static-image burn-in over time. The image ships a
software dimming helper that can be run manually or bound to a hotkey:

```bash
# Dim to the default 70% brightness
g16-oled-dim.sh

# Dim to 50%
g16-oled-dim.sh 50

# Restore full brightness
g16-oled-dim.sh 100
```

The helper prefers KWin Night Color when running under Plasma, and falls back
to `xrandr` or `xgamma` on X11. Wayland users should rely on the KWin path;
if Night Color is not available, install the KWin "Dim Screen" script or use
KDE System Settings > Display > Night Color for scheduled dimming.

## RGB subpixel rendering

The G16 OLED subpixel layout behaves best with RGB subpixel font rendering.
`XftSubPixel=rgb` is set system-wide in `/usr/etc/xdg/kdeglobals`. Users can
override this per-account in **System Settings > Fonts > Sub-pixel rendering**.

## Intel Arc / NPU access

The `intel-arc-npu` module installs udev rules that grant the `render` group
access to:

- `/dev/accel*` — Intel Neural Processing Unit (NPU)
- `/dev/dri/renderD*` — Intel Arc / Xe render nodes

Add your user to the `render` group (and `video` if not already present) and
reboot:

```bash
sudo usermod -aG render,video "$USER"
```

After reboot, verify the NPU device is visible:

```bash
ls -l /dev/accel*
```

## EasyEffects preset

A system-wide EasyEffects preset tuned for the G16 speakers is installed by the
`audio-eq` module and autoloaded on login. The preset lives at:

```
/usr/share/pipewire/presets/easyeffects/g16-speakers.json
```

If you prefer headphones or external speakers, open EasyEffects and create a
new preset; the autoload script will not overwrite a user-defined profile.

## Additional recommendations

- Keep the panel brightness below 80% for daily use to extend OLED lifespan.
- Use a dark Plasma theme and avoid static taskbars or desktop widgets when
  possible; auto-hide the panel to reduce burn-in risk.
- Enable **System Settings > Power > Screen Energy Saving** with a short idle
  timeout.
- For VFIO or GPU passthrough experiments, see the generic VFIO planning notes
  in `/usr/share/doc/secureblue-kde-agentic/README.md`.
