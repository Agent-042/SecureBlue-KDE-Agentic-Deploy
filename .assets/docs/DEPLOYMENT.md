# Deployment Guide

Step-by-step guide for deploying the SecureBlue KDE Agentic image.

## 1. Build or obtain the image

### Local BlueBuild build (development)

```bash
bluebuild build recipes/recipe.yml
```

### GitHub Actions

The workflow in `.github/workflows/build.yml` builds and pushes the image on every push to the default branch. See the README badge for the latest build status.

## 2. Rebase a host

This project builds three fleet images. Use the fleet-aware helper to detect the current hardware and rebase to the matching image:

```bash
# Preview the detected image and command
scripts/rebase.sh --dry-run

# Rebase to the detected image
scripts/rebase.sh

# Verify the image signature with cosign before rebasing
scripts/rebase.sh --verify
```

Or rebase manually to the image for your fleet:

- Default / fallback: `ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest`
- AMD Ryzen 9 9950X workstation (dual RTX 4080, VFIO): `ghcr.io/Agent-042/secureblue-kde-agentic-deploy-amd-workstation:latest`
- Intel Core Ultra 9 G16 laptop (RTX 5080 OLED, Arc/NPU): `ghcr.io/Agent-042/secureblue-kde-agentic-deploy-intel-g16:latest`

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/Agent-042/secureblue-kde-agentic-deploy-amd-workstation:latest
systemctl reboot
```

## 3. Post-install configuration

After first boot:

```bash
# Verify enabled systemd services
systemctl is-enabled pcscd.service libvirtd.service virtlogd.service

# Verify virtualization support
virt-host-validate

# Review installed Flatpaks
flatpak list --app --columns=application

# Restore the project workspace and Kimi Code CLI context.
# This helper is installed at /usr/bin/kimi-resume.sh by the kimi-resume module.
kimi-resume.sh
```

The persistent workspace is at `~/Agentic-OS`, which is symlinked to `/var/lib/agentic-os/<user>` by the persist-workspace module. The project repository is cloned or updated at `~/Agentic-OS/SecureBlue-KDE-Agentic-Deploy`. Keep project repositories and cloud-sync targets under `~/Agentic-OS` so they survive reboots and rebases.

## 4. Hardware token setup

Insert a YubiKey or compatible PC/SC token and confirm:

```bash
pcsc_scan
```

## 5. Browser profile setup

1. Launch **Trivalent** and sign in to Google Workspace / corporate SSO.
2. Launch **Mullvad Browser** from the privacy-browser launcher.
3. Confirm that bookmarks, cookies, and certificates are not shared between the two. See [`BROWSER_POLICY.md`](BROWSER_POLICY.md) for isolation details.

## 6. VFIO / Whonix planning

> **Cryptomining is not included in this image.** Any historical GPU-mining documentation has been moved to the separate `Agent-042/BuildBlue-cryptomining-docs` repository and is **opt-in only**. The image does not ship miner containers, systemd units, or wallet configurations. GPU workloads are limited to optional local AI inference and ethical distributed computing.

IOMMU and KVM are already enabled. To complete VFIO or Whonix-on-KVM:

1. Identify the IOMMU groups for the target device(s):

   ```bash
   #!/bin/bash
   for d in /sys/kernel/iommu_groups/*/devices/*; do
     n=${d#*/iommu_groups/*}; n=${n%%/*}
     printf 'IOMMU Group %s ' "$n"
     lspci -nns "${d##*/}"
   done
   ```

2. Apply per-device `driverctl` overrides or libvirt XML hostdev entries.

   On the AMD workstation image, the `vfio-bind-secondary-gpu.service` can bind the non-primary NVIDIA GPU to `vfio-pci` at boot. Run the helper manually with:

   ```bash
   sudo /usr/bin/vfio-bind-secondary-gpu.sh
   ```

3. For Whonix, import the KVM templates and attach them to an isolated virtual network.

## 7. Local AI

Each fleet image includes an Ollama server; the default and workstation images run it as a Podman Quadlet user service, while the Intel G16 image uses a pre-baked IPEX-LLM system service.

### Podman Quadlet (default / workstation)

```bash
systemctl --user enable --now ollama.service
```

Fleet-specific container images:

- **Default AMD 7800X3D image:** uses `docker.io/ollama/ollama:rocm` for AMD Radeon iGPU acceleration.
- **AMD 9950X workstation:** uses CPU inference (`docker.io/ollama/ollama:latest`) because the host has no AMD iGPU and the NVIDIA RTX 4080s are reserved for display and VFIO passthrough.

Downloaded models persist in the `ollama` Podman volume (`/root/.ollama` inside the container).

### Intel G16 laptop

The Intel G16 image ships a pre-baked `ipex-ollama.service` system service for Intel Arc iGPU and Core Ultra NPU offload via IPEX-LLM.

```bash
sudo systemctl enable --now ipex-ollama.service
```

The service runs `/opt/ipex-llm/bin/ollama serve` and listens on `127.0.0.1:11434`.

## 8. Display calibration

The curated stack includes VibrantLinux for OLED dimming workarounds and SDR saturation boosts inside HDR. It is installed as a Flatpak (`io.github.libvibrant.vibrantLinux`); run it from the application menu or with:

```bash
flatpak run io.github.libvibrant.vibrantLinux
```

If you prefer not to use it, substitute with KDE System Settings → Display → Color Management and Night Color for software dimming and color temperature adjustment.

Kvantum Manager is layered at build time. The macOS Tahoe theme is applied automatically before first login by `tahoe-cosmetic-reset.service`; see [`docs/TAHOE_THEMING.md`](TAHOE_THEMING.md) for customization and troubleshooting.

## Auto-generated recipe summary

The sections below are regenerated by `scripts/generate-docs.py`. Do not edit them manually.

<!-- BEGIN KARGS_SECTION -->
### Kernel arguments

```yaml
kargs:
- amd_iommu=on
- iommu=pt
- kvm.ignore_msrs=1
- kvm_amd.npt=1
- kvm_amd.avic=1
- rd.driver.blacklist=nouveau
- modprobe.blacklist=nouveau
```
<!-- END KARGS_SECTION -->

<!-- BEGIN SERVICES_SECTION -->
### Enabled systemd services

```yaml
systemd:
  system:
    enabled:
    - pcscd.service
    - libvirtd.service
    - virtlogd.service
    - mullvad-daemon.service
    - bluebuild-first-boot.service
    - ollama.service
  user:
    enabled:
    - agentic-workspace-init.service
    - tahoe-cosmetic-reset.service
```
<!-- END SERVICES_SECTION -->

<!-- BEGIN FLATPAK_SECTION -->
### Installed Flatpaks

```yaml
containers:
  flatpaks:
  - net.mullvad.MullvadBrowser
  - org.keepassxc.KeePassXC
  - com.google.Chrome
  - com.yubico.yubioath
  - com.github.wwmm.easyeffects
  - org.mozilla.Thunderbird
  - im.riot.Riot
  - com.vscodium.codium
  - com.github.zocker_160.SyncThingy
  - io.github.libvibrant.vibrantLinux
```
<!-- END FLATPAK_SECTION -->

<!-- BEGIN MODULES_SECTION -->
### Custom modules

- **`agent-stack`** — Self-parsing CLI manifest that installs Kimi Code, Antigravity CLI, and Mullvad VPN. (`modules/agent-stack/module.yml`)
- **`agent-stack-skel`** — Custom BlueBuild module. (`modules/agent-stack-skel/module.yml`)
- **`audio-eq`** — EasyEffects G16 speaker-clarity preset. (`modules/audio-eq/module.yml`)
- **`docs-readme`** — On-image documentation. (`modules/docs-readme/module.yml`)
- **`emergency-rescue`** — Basic network/diagnostic rescue tooling. (`modules/emergency-rescue/module.yml`)
- **`ephemeral-home`** — Optional tmpfs `/var/home` mount (disabled by default). (`modules/ephemeral-home/module.yml`)
- **`flatpak-overrides`** — Sandboxing overrides for default Flatpaks. (`modules/flatpak-overrides/module.yml`)
- **`google-chrome-config`** — Enterprise policy for Google Chrome. (`modules/google-chrome-config/module.yml`)
- **`immutability`** — Redacted SDDM and powerdevil policies. (`modules/immutability/module.yml`)
- **`intel-arc-npu`** — Custom BlueBuild module. (`modules/intel-arc-npu/module.yml`)
- **`kimi-resume`** — Post-login helper to restore the project repo and Kimi CLI. (`modules/kimi-resume/module.yml`)
- **`local-ai`** — Ollama Podman Quadlet. (`modules/local-ai/module.yml`)
- **`local-ai-amd-workstation`** — Custom BlueBuild module. (`modules/local-ai-amd-workstation/module.yml`)
- **`local-ai-intel-g16`** — IPEX-LLM Ollama systemd service for Intel Arc iGPU and Core Ultra NPU offload. (`modules/local-ai-intel-g16/module.yml`)
- **`network-lockdown`** — Mullvad defaults and Chrome split-tunnel routing. (`modules/network-lockdown/module.yml`)
- **`oled-g16-tuning`** — Custom BlueBuild module. (`modules/oled-g16-tuning/module.yml`)
- **`persist-workspace`** — Persistent `~/Agentic-OS` workspace. (`modules/persist-workspace/module.yml`)
- **`privacy-browser-config`** — Isolated research browser launcher. (`modules/privacy-browser-config/module.yml`)
- **`tahoe-theming`** — macOS Tahoe-inspired WhiteSur theme with true-black panels, dock, and left stoplights. (`modules/tahoe-theming/module.yml`)
- **`trivalent-config`** — Enterprise policy for Trivalent. (`modules/trivalent-config/module.yml`)
- **`trivalent-rpm`** — Hardened Trivalent browser RPM. (`modules/trivalent-rpm/module.yml`)
- **`vfio-sandbox`** — VFIO module loading for PCI passthrough. (`modules/vfio-sandbox/module.yml`)
- **`vfio-workstation`** — Custom BlueBuild module. (`modules/vfio-workstation/module.yml`)
<!-- END MODULES_SECTION -->
