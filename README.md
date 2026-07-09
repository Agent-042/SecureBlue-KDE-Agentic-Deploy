# SecureBlue KDE Agentic Deploy

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

1. Install Fedora Atomic KDE or rebase from an existing Fedora Atomic installation.
2. Run the rebase command (replace `YOUR_IMAGE_REF` with the built image tag):

   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
   ```

3. Reboot.
4. After first boot, restore the persistent project workspace by running `kimi-resume.sh` (installed at `/usr/bin/kimi-resume.sh`).
5. Verify the pre-configured systemd services and Flatpak overrides described in [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

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

See [`docs/BROWSER_POLICY.md`](docs/BROWSER_POLICY.md) for full details.

## Hardening Checklist

- [x] SecureBlue KDE hardened base image
- [x] Kernel IOMMU (`amd_iommu=on`, `iommu=pt`) for device isolation
- [x] MSRS ignored for KVM compatibility (`kvm.ignore_msrs=1`)
- [x] AMD microcode updates and Radeon iGPU drivers layered
- [x] VFIO modules loaded for virtual device sandboxing
- [x] Persistent `~/Agentic-OS` workspace survives reboots/rebases
- [x] `pcscd` enabled for hardware token/YubiKey support
- [x] Libvirt/QEMU/KVM virtualization stack installed and enabled
- [x] Flatpak applications sandboxed via system-wide overrides
- [x] Enterprise and privacy browser profiles isolated
- [x] Google Chrome (enterprise browser) and Yubico Authenticator (hardware token 2FA/TOTP) preinstalled as Flatpaks
- [x] Mullvad VPN client preinstalled via RPM repository

## VFIO / Whonix Note

IOMMU and KVM are enabled for future VFIO pass-through and Whonix-on-KVM isolation. Additional per-device ACS/ID grouping and libvirt XML configuration are required and should be applied after installation. See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the planning section.

## Build Status

![Build](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/actions/workflows/build.yml/badge.svg)

## Documentation

- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — step-by-step deployment guide
- [`docs/BROWSER_POLICY.md`](docs/BROWSER_POLICY.md) — browser profile and certificate isolation details
- [`scripts/generate-docs.py`](scripts/generate-docs.py) — regenerate deployment docs from `recipes/recipe.yml`
