# SecureBlue KDE Agentic Deploy — Application Guides

This directory contains per-application installation and configuration guides following the **BuildBlue dual-format specification**.

## Format Specification

Each guide is split into two sections:

- **`## Human Logic ##`**  
  Step-by-step manual commands for post-install configuration on a running system.  
  Each command is separated by a blank line for easy copy-paste.

- **`## Script Logic ##`**  
  BlueBuild / uBlue module configuration for baking the application directly into the immutable image.  
  Copy these snippets into the appropriate `module.yml` or recipe file.

## Guide Index

| Application | Type | Guide |
|---|---|---|
| Google Chrome | Flatpak | [`google-chrome.md`](google-chrome.md) |
| Mullvad VPN | RPM + Service | [`mullvad-vpn.md`](mullvad-vpn.md) |
| Mullvad Browser | Flatpak | [`mullvad-browser.md`](mullvad-browser.md) |
| KeePassXC | Flatpak | [`keepassxc.md`](keepassxc.md) |
| EasyEffects | Flatpak | [`easyeffects.md`](easyeffects.md) |
| Thunderbird | Flatpak | [`thunderbird.md`](thunderbird.md) |
| Element (Riot) | Flatpak | [`element-riot.md`](element-riot.md) |
| VSCodium | Flatpak | [`vscodium.md`](vscodium.md) |
| Syncthingy | Flatpak | [`syncthingy.md`](syncthingy.md) |
| Yubico Authenticator | Flatpak | [`yubico-authenticator.md`](yubico-authenticator.md) |
| Trivalent Browser | RPM | [`trivalent-browser.md`](trivalent-browser.md) |
| Privacy/Research Browser | System Script | [`privacy-browser.md`](privacy-browser.md) |
| Flatpak Overrides | System Hardening | [`flatpak-overrides.md`](flatpak-overrides.md) |
| Audio EQ | System Service | [`audio-eq.md`](audio-eq.md) |
| Tahoe Theming | System Config | [`tahoe-theming.md`](tahoe-theming.md) |
| Network Lockdown | System Policy | [`network-lockdown.md`](network-lockdown.md) |
| VFIO Sandbox | Kernel / KVM | [`vfio-sandbox.md`](vfio-sandbox.md) |
| Emergency Rescue | System Script | [`emergency-rescue.md`](emergency-rescue.md) |
| Immutability | System Config | [`immutability.md`](immutability.md) |
| Persist Workspace | System Service | [`persist-workspace.md`](persist-workspace.md) |
| Agent Stack | System Service | [`agent-stack.md`](agent-stack.md) |
| Local AI (Ollama) | Container | [`local-ai.md`](local-ai.md) |
| OLED G16 Tuning | Hardware Script | [`oled-g16-tuning.md`](oled-g16-tuning.md) |
| Kimi Resume | Helper Script | [`kimi-resume.md`](kimi-resume.md) |

## Quick Reference

**Adding a new Flatpak to the image:**
```yaml
modules:
  - type: default-flatpaks
    system:
      install:
        - com.example.App
```

**Adding a new system file override:**
```yaml
type: files
files:
  - source: my-module/usr
    destination: /usr
```

**Creating a new guide:**
1. Copy an existing guide as a template
2. Fill in `## Human Logic ##` with exact commands
3. Fill in `## Script Logic ##` with module and file configs
4. Add the guide to the index above
5. Open a PR or push directly (you have the PAT)
