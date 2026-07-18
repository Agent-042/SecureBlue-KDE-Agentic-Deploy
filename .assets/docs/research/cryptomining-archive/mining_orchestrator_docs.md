# Mining Orchestrator Documentation

This document describes the rootless Podman-based mining/orchestration setup
built on the local SecureBlue host `/var/home/agent-42`.

---

## 1. Architecture Overview

The orchestrator runs as a set of rootless Podman Quadlet units managed by the
user systemd instance. It supports:

- **CPU Monero mining** — `xmr-miner` runs XMRig inside a rootless container.
- **GPU MoneroOcean profit switching** — `alph-miner` now runs MoneroOcean's
  `multi-miner` shim + Rigel, allowing the RTX 4080 to switch between the
  most profitable GPU algorithms (`autolykos2`, `etchash`, `kawpow`).
- **Ethical alternatives** — `folding` (Folding@home, can use the GPU) and
  `ollama` (local LLM inference on CPU) can replace the miners.
- **VFIO hook** — a libvirt QEMU hook that stops the GPU miner, unbinds the
  RTX 4080 from the NVIDIA driver, and binds it to `vfio-pci` whenever a
  Windows 11 VM starts; reverses the process when the VM stops.
- **Idle monitor** — `idle_monitor.sh` starts the miners only after the desktop
  session has been idle for a configurable threshold, and stops them on activity.

All services are defined as Quadlet `.container` files, so Podman generates the
user systemd units automatically.

---

## 2. Hardware and Assumptions

- **GPU:** NVIDIA GeForce RTX 4080 (used for MoneroOcean profit-switching GPU
  mining; optional passthrough to a Windows 11 VM via the VFIO hook).
- **CPU:** AMD Ryzen 7 7800X3D (used by the Monero CPU miner).
- **Host OS:** SecureBlue (Fedora Atomic/Silverblue-based hardened desktop).
- **Cost assumption:** electricity is treated as zero-cost for this test setup.
- **Rootless Podman** is the intended runtime; root privileges are only required
  for the kernel setting, NVIDIA CDI generation, SELinux boolean, and VFIO hook
  deployment.

---

## 3. Files Created and Their Purposes

### Quadlet container definitions

| Path | Purpose |
|------|---------|
| `~/.config/containers/systemd/xmr-miner.container` | Rootless XMRig CPU Monero miner service. |
| `~/.config/containers/systemd/alph-miner.container` | Rootless MoneroOcean GPU profit-switching service (multi-miner + Rigel) with NVIDIA CDI passthrough. |
| `~/.config/containers/systemd/folding.container` | Folding@home ethical distributed computing container. |
| `~/.config/containers/systemd/ollama.container` | Ollama local LLM inference container. |

### Supporting files

| Path | Purpose |
|------|---------|
| `~/.config/xmrig/config.json` | XMRig configuration (pool, wallet address, CPU threads). |
| `~/mo-gpu-miner.Containerfile` | Container recipe for the MoneroOcean profit-switching GPU miner (multi-miner + Rigel). |
| `~/.config/mo-gpu-miner/mm.json` | multi-miner configuration (pool, wallet, per-algo Rigel commands, algo_perf). |
| `~/idle_monitor.sh` | Starts/stops miners based on desktop idle state. |
| `~/deploy-hook.sh` | Helper that installs `qemu-hook-temp` into `/etc/libvirt/hooks/qemu` using `run0`. |
| `~/qemu-hook-temp` | Libvirt QEMU hook script for VFIO GPU passthrough. |
| `~/wallets.txt` | Public test addresses for Monero and Alephium. |
| `~/wallet_work/` | **Sensitive directory** containing generated wallet files, mnemonics, and private keys. |

### Generated wallet artifacts inside `~/wallet_work/`

| File | Purpose |
|------|---------|
| `gen_alph_wallet.py` | Script that generated the Alephium test wallet. |
| `alph_wallet.txt` | Alephium mnemonic and address. |
| `alph_address.txt` | Alephium public address only. |
| `alph_out.txt` | Additional generated Alephium wallet output. |
| `xmr_address.txt` | Monero public address. |
| `xmr_out.txt` | `monero-wallet-cli` output. |
| `xmr_wallet` / `xmr_wallet.keys` | Monero wallet files (contain private keys). |
| `pass.txt` | Wallet passphrase used during generation. |

---

## 4. Enable Rootless Podman on SecureBlue

SecureBlue hardens the kernel so that unprivileged user namespaces are disabled.
Podman in rootless mode requires this feature, so it must be enabled first.

### Interactive method (applies immediately, lost on reboot unless persisted)

```bash
run0 sysctl kernel.unprivileged_userns_clone=1
```

### Persistent method via kernel arguments (recommended)

```bash
run0 rpm-ostree kargs --append=kernel.unprivileged_userns_clone=1
run0 systemctl reboot
```

After reboot, verify:

```bash
sysctl kernel.unprivileged_userns_clone
```

It must return `1` for rootless Podman to work.

---

## 5. Generate the NVIDIA CDI Spec

The Alephium miner uses CDI to access the GPU. The NVIDIA module must be loaded
and `nvidia-ctk` must be available.

Generate the CDI specification:

```bash
run0 nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Verify it was generated correctly:

```bash
run0 nvidia-ctk cdi list
```

You should see a device such as `nvidia.com/gpu=0` listed. If the NVIDIA module
is not loaded, load it first:

```bash
run0 modprobe nvidia
```

---

## 6. Set the SELinux Boolean

Containers need permission to use host devices (including CDI GPUs):

```bash
run0 setsebool -P container_use_devices true
```

---

## 7. Deploy the libvirt VFIO Hook

The hook must be installed into `/etc/libvirt/hooks/qemu`. The helper script
uses `run0`, so run it interactively:

```bash
~/deploy-hook.sh
```

Then restart libvirtd if it is already running:

```bash
run0 systemctl restart libvirtd
```

### Important hook configuration

Open `~/qemu-hook-temp` and replace the placeholder PCI address with the actual
RTX 4080 address:

```bash
lspci | grep -i nvidia
```

Edit this line in `~/qemu-hook-temp` before deploying:

```bash
PCI_ADDR="0000:01:00.0"
```

The hook reacts only to a VM named `Windows11`.

---

## 8. Start and Stop the Miners

Quadlet generates user systemd units from the `.container` files. After editing
any Quadlet file, reload the user manager:

```bash
systemctl --user daemon-reload
```

Start the miners:

```bash
systemctl --user start xmr-miner alph-miner
```

Stop the miners:

```bash
systemctl --user stop xmr-miner alph-miner
```

Check status:

```bash
systemctl --user status xmr-miner alph-miner
```

To start them automatically on login:

```bash
systemctl --user enable xmr-miner alph-miner
```

---

## 9. Switch to Ethical Alternatives

Stop the miners and start Folding@home and Ollama:

```bash
systemctl --user stop xmr-miner alph-miner
systemctl --user start folding ollama
```

Check status:

```bash
systemctl --user status folding ollama
```

### Notes on ethical containers

- `folding.container` is configured for anonymous folding. Replace
  `FOLD_PASSKEY=REPLACE_WITH_YOUR_PASSKEY` with your own passkey if desired.
- `ollama.container` exposes the API only on `127.0.0.1:11434` and uses CPU by
  default. To use the GPU, add `AddDevice=nvidia.com/gpu=all` to the container
  file.

---

## 10. Idle Monitor

`~/idle_monitor.sh` starts the miners when the session is idle and stops them
when activity resumes.

### How it works

- Default idle threshold: **5 minutes** (`IDLE_SECONDS=300`).
- Poll interval: **10 seconds** when `swayidle` is not installed.
- If `swayidle` is available, it is used as the idle detector.
- Otherwise, the script polls `loginctl show-session <session> -p IdleHint`.
- When idle is detected continuously for the threshold, it runs:

  ```bash
  systemctl --user start xmr-miner alph-miner
  ```

- On resume/activity, it runs:

  ```bash
  systemctl --user stop xmr-miner alph-miner
  ```

### Usage

Start the monitor:

```bash
~/idle_monitor.sh start
```

Stop the monitor and miners:

```bash
~/idle_monitor.sh stop
```

Restart:

```bash
~/idle_monitor.sh restart
```

Logs are written to `${XDG_RUNTIME_DIR}/idle_monitor.log` (usually
`/run/user/1000/idle_monitor.log`).

---

## 11. VFIO Hook Flow

The hook is invoked by libvirt for the `Windows11` VM.

### `prepare` / `begin` — VM is starting

1. Stop the GPU miner:

   ```bash
   systemctl --user stop alph-miner
   ```

2. Check the driver bound to `PCI_ADDR`.
3. If it is `nvidia`, unbind it and bind `vfio-pci`:

   ```bash
   echo '0000:01:00.0' > /sys/bus/pci/drivers/nvidia/unbind
   echo 'vfio-pci' > /sys/bus/pci/devices/0000:01:00.0/driver_override
   echo '0000:01:00.0' > /sys/bus/pci/drivers/vfio-pci/bind
   ```

### `release` / `stopped` — VM has stopped

1. Unbind the GPU from `vfio-pci`:

   ```bash
   echo '0000:01:00.0' > /sys/bus/pci/drivers/vfio-pci/unbind
   echo > /sys/bus/pci/devices/0000:01:00.0/driver_override
   ```

2. Reload the NVIDIA driver and rescan the PCI bus:

   ```bash
   modprobe nvidia || true
   echo 1 > /sys/bus/pci/rescan
   ```

3. Restart the idle monitor so mining resumes according to idle rules:

   ```bash
   ~/idle_monitor.sh restart
   ```

---

## 12. Security Note: Wallet Artifacts

The `~/wallet_work/` directory contains sensitive material generated during this
test run, including:

- Monero wallet files (`xmr_wallet`, `xmr_wallet.keys`)
- Alephium mnemonic phrases
- Wallet passphrases

For a production deployment:

1. Move the required wallet address (public) into your secure password manager
   or secrets store.
2. Delete the entire `~/wallet_work/` directory:

   ```bash
   rm -rf ~/wallet_work
   ```

3. Update `~/.config/xmrig/config.json` to reference your production Monero
   address (and pool) instead of the test address.

The public test addresses are only recorded in `~/wallets.txt` for reference.

---

## 13. Current Status / Blockers

As of the latest optimization pass, both miners are **running continuously**
under the free-electricity assumption.

### What is running

- `xmr-miner` — XMRig RandomX on the Ryzen 7 7800X3D, tuned to 16 threads,
  producing ~9 kH/s with 100% huge-page allocation.
- `alph-miner` — MoneroOcean `multi-miner` + Rigel on the RTX 4080,
  profit-switching across `autolykos2`, `etchash`, and `kawpow`. Currently
  mining `autolykos2` at ~155 MH/s.
- `mining-stats.service` — logs container status and hashrate every 15 minutes
  to `~/mining_stats.log`.

### Operational choices

- `folding` has been stopped and disabled to free GPU time for revenue mining.
- The idle monitor is **not** running; with free electricity the miners are
  left on continuously for maximum 24h payout.
- The VFIO hook is still not deployed. Run `~/deploy-hook.sh` only if you want
  to pass the RTX 4080 through to a Windows 11 VM; otherwise the GPU stays
  available for mining.

### Remaining blockers

- None for the current CPU/GPU mining setup.
- If you reboot, ensure `/etc/cdi/nvidia.yaml` is still present and rootless
  Podman still works; the miners will start automatically via the generated
  Quadlet units and `mining-stats.service`.


