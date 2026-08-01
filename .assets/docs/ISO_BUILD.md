# ISO Build Guide

Create a bootable installation ISO from the signed OCI image. This is useful for bare-metal installs or for building a recovery USB that already points at the desired fleet image.

## Prerequisites

- A Linux host with `podman`, `cosign`, and `coreos-installer` installed.
- The `cosign.pub` public key from this repository.
- Enough free disk space for the container image and ISO (~10 GB minimum).

## 1. Verify the signed image

Before generating media, verify the image signature:

```bash
cd ~/Agentic-OS/SecureBlue-KDE-Agentic-Deploy
cosign verify --key cosign.pub \
  ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
```

Replace the image reference with the fleet-specific tag if needed:

```bash
cosign verify --key cosign.pub \
  ghcr.io/Agent-042/secureblue-kde-agentic-deploy-amd-workstation:latest
cosign verify --key cosign.pub \
  ghcr.io/Agent-042/secureblue-kde-agentic-deploy-intel-g16:latest
```

## 2. Pull the OCI image

```bash
podman pull ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
```

## 3. Option A: Generate a raw disk image with rpm-ostree

`rpm-ostree compose image` produces a bootable raw/qcow2 disk image from the OSTree container. This image can be written directly to a disk or converted to other formats.

```bash
mkdir -p ./output
podman run --rm --privileged \
  -v ./output:/output:Z \
  -v /var/lib/containers:/var/lib/containers:Z \
  registry.fedoraproject.org/fedora:latest \
  rpm-ostree compose image \
    --format qcow2 \
    --cachedir /tmp/rpm-ostree-cache \
    ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest \
    /output/secureblue-kde-agentic-deploy.qcow2
```

Convert to a raw image if needed:

```bash
qemu-img convert -f qcow2 -O raw \
  ./output/secureblue-kde-agentic-deploy.qcow2 \
  ./output/secureblue-kde-agentic-deploy.raw
```

## 4. Option B: Generate an installable ISO with coreos-installer

The most practical install media starts from the upstream Fedora Kinoite ISO and embeds the target OSTree remote, ref, and optionally an Ignition config.

1. Download the Fedora Kinoite ISO:

   ```bash
   curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/40/Kinoite/x86_64/iso/Fedora-Kinoite-ostree-x86_64-40-1.14.iso
   ```

2. Customize the ISO to point at the signed image:

   ```bash
   coreos-installer iso customize \
     --dest-ostree-remote agentic \
     --dest-ostree-ref "fedora/$(rpm -E %fedora)/x86_64/kinoite" \
     --network-keyfile ./agentic.nmconnection \
     -o ./output/secureblue-kde-agentic-deploy-installer.iso \
     Fedora-Kinoite-ostree-x86_64-40-1.14.iso
   ```

   The exact `--dest-ostree-ref` depends on the base image used by the recipe. Inspect the pulled image or the recipe `base-image:` field to determine the correct ref. For many BlueBuild/SecureBlue images the installer will rebase from the embedded container pull after first boot, so the ref can also be set via a post-install service or Ignition.

3. The resulting ISO boots into the Fedora installer, which pulls and deploys the signed OSTree commit.

## 5. Flash the ISO to USB

Use Fedora Media Writer, `dd`, or another trusted tool:

```bash
# Replace /dev/sdX with the target USB device.
sudo dd if=./output/secureblue-kde-agentic-deploy-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Fedora Media Writer is recommended for users on Windows or macOS because it handles hybrid ISOs correctly and can verify the written media.

## 6. First boot and verification

After installation, verify the running deployment:

```bash
rpm-ostree status
cosign verify --key cosign.pub \
  "ghcr.io/Agent-042/$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference" | split(":")[0]'):latest"
```

On first login, restore the persistent workspace:

```bash
kimi-resume.sh
```

## Automated helper

See [`scripts/generate-iso.sh`](../scripts/generate-iso.sh) for a skeleton script that pulls the image and produces output media. Edit the placeholders for your host environment before running it.
