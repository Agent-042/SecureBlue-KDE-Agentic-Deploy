# BuildBlue Cryptomining Documentation Archive

This repository contains historical, documentation-only artifacts from a rootless Podman-based cryptocurrency mining test stack built on a SecureBlue KDE host. It is published for BuildBlue reference and is **not** part of the SecureBlue KDE Agentic Deploy image.

## Important notes

- **Documentation only.** Nothing in this repo is executed, installed, or enabled by default in the BuildBlue / SecureBlue KDE image.
- **Wallet values are placeholders.** Any miner configuration files have had their wallet addresses and worker names replaced with `YOUR_WALLET_ADDRESS`, `YOUR_GPU_WORKER_NAME`, and `YOUR_CPU_WORKER_NAME`. You must substitute your own addresses before use.
- **No private keys.** Wallet private keys, mnemonics, or passphrases are not included here.
- **No warranty.** These configurations were tuned for a specific test machine (AMD Ryzen 7 7800X3D + NVIDIA RTX 4080). Use at your own risk.

## Repository layout

- `BuildBlue-alph-miner-runbook.md` — Runbook for the RTX 4080 MoneroOcean profit-switching GPU miner.
- `mining_orchestrator_docs.md` — Architecture overview of the CPU/GPU mining orchestrator, VFIO hook, and idle monitor.
- `*.Containerfile` — Container recipes for the GPU miner (`mo-gpu-miner`), CPU miner (`cpu-miner`), and an older GPU miner (`gpu-miner`).
- `*.sh` — Supporting scripts: watchdog, cleanup, idle monitor, VFIO hook deployment, stats logger, summary generator.
- `qemu-hook-temp` — Libvirt QEMU hook template for stopping the GPU miner and binding the RTX 4080 to `vfio-pci` when a Windows 11 VM starts.
- `.config/containers/systemd/*.container` — Podman Quadlet container unit files.
- `.config/systemd/user/*.service` / `*.timer` — systemd user unit files.
- `.config/mo-gpu-miner/mm.json.example` — Sanitized Multi-Miner / Rigel configuration example.
- `.config/xmrig/config.json.example` — Sanitized XMRig configuration example.

## Relationship to SecureBlue KDE Agentic Deploy

The SecureBlue KDE Agentic Deploy image does **not** include these mining components. GPU workloads in that image are limited to optional local AI inference (Ollama) and ethical distributed computing (Folding@home). If you want to run a miner, clone this repository, replace the placeholder wallet values, and manually deploy the units on a suitable host.

## License

No explicit license is attached. These files are provided as reference material only.
