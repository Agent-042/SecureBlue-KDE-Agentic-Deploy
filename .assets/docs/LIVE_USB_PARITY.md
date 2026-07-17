# Live USB Parity

This image is designed to look and behave the same whether it boots from a USB stick or is installed to internal storage.

## What works out of the box on live USB

- **Flatpak:** Flathub is pre-configured and user-scope Flatpaks install into `~/.local/share/flatpak/` on the overlay filesystem. No `rpm-ostree` or root is needed.
- **Theming:** `tahoe-cosmetic-reset.service` runs before Plasma on first login, so the macOS Tahoe look is applied before the desktop appears.
- **Preinstalled system packages:** Kvantum, Inter font, virtualization stack, browsers, Mullvad VPN, and YubiKey support are baked into the image.
- **Preinstalled Flatpaks:** KeePassXC, Yubico Authenticator, EasyEffects, Thunderbird, VSCodium, Chrome, Mullvad Browser, and Syncthing are installed at the system scope.
- **Local AI:** The Ollama Podman Quadlet can be enabled per-user with `systemctl --user enable --now ollama.service`.

## Session persistence

The SecureBlue live USB uses an overlay filesystem (`LiveOS_rootfs`). Any change written to `/` (including user Flatpaks, config edits, and files in `/var/home`) persists until shutdown. On reboot the overlay is discarded, returning the stick to its original state.

This makes the live image useful as a disposable, hardened DevOps environment — like Tails, but oriented toward agentic workflows rather than anonymity (use Whonix-on-KVM for anonymity work).

## Extracting work before shutdown

Because the overlay is RAM-backed, copy anything you want to keep off the live system before rebooting:

```bash
# To a second USB drive
mkdir -p /run/media/$USER/BACKUP
cp -r ~/Agentic-OS /run/media/$USER/BACKUP/

# Or push to the GitHub repo from a working network location
kimi-resume.sh
git add . && git commit -m "live USB notes" && git push
```

## Installing to disk

When you install to internal storage, the same theming, packages, Flatpaks, and systemd services carry over automatically. After first boot:

```bash
kimi-resume.sh          # restore the project workspace
systemctl is-enabled tahoe-cosmetic-reset.service
```

The persistent `~/Agentic-OS` workspace survives reboots and rebases.

## Live-USB-specific limitations

- `rpm-ostree install` does not work on live media; packages must be baked into the ISO via the recipe.
- User-scope Flatpaks vanish after reboot unless you install them again or install to disk.
- Large local AI models downloaded inside the live session should be copied out before shutdown.
