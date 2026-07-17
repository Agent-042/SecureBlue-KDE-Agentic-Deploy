# SecureBlue KDE Agentic Deploy

> **SECURITY AUDIT** — This repository contains the following patterns that require operator awareness before use in production or on air-gapped systems:
>
> 1. **`curl | bash` install patterns** — Several scripts download and execute remote installers without local checksum verification:
>    - `install-agent-stack.sh` → `https://code.kimi.com/kimi-code/install.sh`
>    - `install-agent-stack.sh` → `https://antigravity.google/cli/install.sh`
>    - `install-agent-stack.sh` → `https://rpm.nodesource.com/setup_22.x`
>    - `vibrant-linux-install.sh` → `https://github.com/libvibrant/vibrantLinux/releases/download/PLACEHOLDER/vibrantlinux`
>    - `install-agent-stack.sh` → `https://github.com/ollama/ollama/releases/download/v0.5.7/ollama-linux-amd64`
>
> 2. **Pre-compiled binaries downloaded at runtime** — The agent-stack installer fetches unverified amd64 ELF binaries (Ollama, VibrantLinux) directly from GitHub releases. No GPG signatures, Cosign verification, or SHA256SUM checks are performed during download.
>
> 3. **Hardcoded API keys and secrets** — The following sensitive values are embedded in source files:
>    - `mullvad-bootstrap.sh` → Mullvad account number: `1532954861423045`
>    - `scrape-macos-icons.sh` → API key references: `MACOS_ICONS_API_KEY`, `MACOSICONS_API_KEY` (read from environment at runtime)
>    - `install-agent-stack.sh` / `env-init.sh` / `github-api.sh` / `set-signing-secret.sh` / `push-live-status.sh` → GitHub PAT (`GITHUB_PAT`), Gemini API key (`GEMINI_API_KEY`), Kimi API key (`KIMI_API_KEY`) expected in environment
>    - `generate-cosign-keys.sh` / `generate-iso.sh` / `rebase.sh` → Cosign public key path: `cosign.pub`
>
> **Mitigation:** Run `env-init.sh` to load secrets into the current shell session only (never written to disk). Set `GITHUB_PAT` as a GitHub Actions encrypted secret. Rotate the Mullvad account number if this repository is public. Consider vendoring the Ollama binary into the image build rather than fetching at runtime.

A hardened, immutable Fedora Atomic KDE OCI image built with [BlueBuild](https://blue-build.org/) on top of [SecureBlue](https://github.com/secureblue/secureblue).

## Purpose

This project produces a locked-down, reproducible desktop operating system image for a high-assurance, agentic workflow. It combines SecureBlue's hardening with tailored kernel arguments, virtualization support, hardware token integration, and sandboxed browser isolation.

## Target Hardware

- **CPU:** AMD Ryzen 7 7800X3D
- **Motherboard:** Gigabyte B650 AORUS ELITE AX
- **iGPU:** AMD Radeon (Mesa/Radeon drivers)
- **RAM:** 32 GB
- **Base image:** `ghcr.io/secureblue/kinoite-main-hardened:latest`

## Install / Rebase

This project builds three fleet images. Use `./rebase.sh` to detect the
current host and rebase to the matching image, or run the equivalent
`rpm-ostree rebase` command manually.

### Fleet targets

- **Default / fallback:** `ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest`
- **AMD workstation:** `ghcr.io/Agent-042/secureblue-kde-agentic-deploy-amd-workstation:latest`
  (AMD Ryzen 9 9950X, dual NVIDIA RTX 4080, VFIO secondary-GPU binding)
- **Intel G16 laptop:** `ghcr.io/Agent-042/secureblue-kde-agentic-deploy-intel-g16:latest`
  (Intel Core Ultra 9, NVIDIA RTX 5080 OLED, Intel Arc / NPU support)

### Rebase helper

```bash
# Detect the host and print the matching rebase command
./rebase.sh --dry-run

# Rebase to the detected image
./rebase.sh

# Verify the signed image with cosign before rebasing
./rebase.sh --verify
```

Manual rebase (replace `YOUR_IMAGE_REF` with the built image tag):

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
```

Then reboot. After first boot, restore the persistent project workspace by running `/usr/bin/kimi-resume.sh`. Verify the pre-configured systemd services and Flatpak overrides described in [`.assets/docs/DEPLOYMENT.md`](.assets/docs/DEPLOYMENT.md).

## Workspace Layout

This project uses a single, persistent workspace that survives reboots and rebases:

- `~/Agentic-OS` is a symlink to `/var/lib/agentic-os/<user>`.
- The project repository lives at `~/Agentic-OS/SecureBlue-KDE-Agentic-Deploy`.
- `kimi-resume.sh` clones or updates this repository after a fresh deployment and confirms that the Kimi Code CLI is available.

Use `~/Agentic-OS` for project repositories, cloud-sync targets, and any state that must persist across system updates.

## Browser Policy Summary

- **Trivalent** (`trivalent-config`): Hardened enterprise Chromium profile. Forces dark mode, allows Google/Microsoft/Okta/OneLogin SSO/SAML cookies, enables enterprise reporting, and ships managed bookmarks.
- **Google Chrome** (`google-chrome-config`): Additional enterprise browser with the same SSO/dark-mode policy goals as Trivalent, managed via a separate Chrome policy path.
- **Mullvad Browser** (`privacy-browser-config`): Isolated research browser with a dedicated profile and certificate store, hardened DNS/proxy settings, and no cross-contamination with the enterprise browser.

See [`.assets/docs/BROWSER_POLICY.md`](.assets/docs/BROWSER_POLICY.md) for full details.

## Hardening Checklist

- [x] SecureBlue KDE hardened base image
- [x] Kernel IOMMU (`amd_iommu=on` / `intel_iommu=on`, `iommu=pt`) for device isolation
- [x] MSRS ignored for KVM compatibility (`kvm.ignore_msrs=1`)
- [x] AMD / Intel microcode updates and platform graphics drivers layered per fleet
- [x] VFIO modules loaded for virtual device sandboxing; workstation recipe binds secondary NVIDIA GPU
- [x] Persistent `~/Agentic-OS` workspace survives reboots/rebases
- [x] `pcscd` enabled for hardware token/YubiKey support
- [x] Libvirt/QEMU/KVM virtualization stack installed and enabled
- [x] Flatpak applications sandboxed via system-wide overrides
- [x] Enterprise and privacy browser profiles isolated
- [x] Google Chrome (enterprise browser) and Yubico Authenticator (hardware token 2FA/TOTP) preinstalled as Flatpaks
- [x] Mullvad VPN client preinstalled via RPM repository with udp2tcp obfuscation and lockdown mode enabled
- [x] Multi-fleet images: default AMD 7800X3D, AMD 9950X workstation, Intel G16 laptop
- [x] macOS Tahoe-inspired WhiteSur KDE theme with true-black panels, dock, and left stoplights
- [x] Live USB parity: Flatpaks, theming, and workspace helpers work before installation

## VFIO / Whonix Note

IOMMU and KVM are enabled for future VFIO pass-through and Whonix-on-KVM isolation. Additional per-device ACS/ID grouping and libvirt XML configuration are required and should be applied after installation. See [`.assets/docs/DEPLOYMENT.md`](.assets/docs/DEPLOYMENT.md) for the planning section.

## Build Status

![Build](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/actions/workflows/build.yml/badge.svg)

## Documentation

- [`.assets/docs/DEPLOYMENT.md`](.assets/docs/DEPLOYMENT.md) — step-by-step deployment guide
- [`.assets/docs/BROWSER_POLICY.md`](.assets/docs/BROWSER_POLICY.md) — browser profile and certificate isolation details
- [`.assets/docs/TAHOE_THEMING.md`](.assets/docs/TAHOE_THEMING.md) — macOS Tahoe-inspired KDE theme details
- [`.assets/docs/LIVE_USB_PARITY.md`](.assets/docs/LIVE_USB_PARITY.md) — live USB behavior and limitations
- [`.backend/scripts/legacy/generate-docs.py`](.backend/scripts/legacy/generate-docs.py) — regenerate deployment docs from `.backend/recipes/recipe.yml`

## Repository Structure

```
.
├── *.sh                          # SPDM manifests (Self-Parsing Deployment Manifest)
│                                 #   Run with --bluebuild to emit AST, or execute normally
├── .assets/docs/                 # Markdown documentation
│   ├── BROWSER_POLICY.md
│   ├── DEPLOYMENT.md
│   ├── LIVE_USB_PARITY.md
│   └── TAHOE_THEMING.md
├── .backend/                     # Backend build assets (hidden from storefront)
│   ├── recipes/                  # BlueBuild recipe YAML files
│   ├── modules/                  # BlueBuild module configurations
│   ├── files/                    # Files injected into the image by modules
│   ├── scripts/legacy/           # Original pre-SPDM scripts (archived)
│   ├── Justfile                  # Just task runner definitions
│   ├── paint_recipe.py           # Recipe painting helper
│   ├── agent_bootstrap.py        # Agent bootstrap script
│   └── swarm_ledger.json         # Swarm verification ledger
├── .github/workflows/            # GitHub Actions CI/CD
│   └── build.yml
├── cosign.pub                    # Cosign public key for image verification
└── README.md                     # This file
```
