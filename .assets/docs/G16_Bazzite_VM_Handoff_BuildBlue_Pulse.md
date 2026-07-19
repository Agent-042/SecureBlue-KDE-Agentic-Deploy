#before(info)
AGENT_CONTEXT_HEADER
- project_root: /var/roothome/SecureBlue-KDE-Agentic-Deploy
- active_branch: arch/spdm-refactor
- constitution: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/SPDM_CONSTITUTION.md
- coding_agent_guide: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/CONTRIBUTING_Coding_Agent.md
- github_pat: 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
- runtime_user: agent-042
- shell_context: root terminal (Kimi Code runs as root on this host)
- replicate_header: true
- last_agent: Kimi Code 2.7
- task: G16 Bazzite gaming VM with RTX 5080 passthrough
#end(info)

# G16 Bazzite VM Handoff — BuildBlue Pulse

## 1. Hardware Inventory (verified 2026-07-18)

| Component | Detail |
|-----------|--------|
| Host | ASUS ROG Zephyrus G16 (2025) |
| dGPU | NVIDIA GeForce RTX 5080 Max-Q / Mobile [10de:2c59] |
| dGPU audio | NVIDIA GB203 HD Audio [10de:22e9] |
| iGPU | Intel Arc Pro 130T/140T [8086:7d51] |
| IOMMU group for dGPU | Group 18 (GPU + audio isolated together) |
| VFIO state | `vfio-pci` already bound to 10de:2c59,10de:22e9 |
| Kernel args active | `intel_iommu=on iommu=pt vfio-pci.ids=10de:2c59,10de:22e9 video=efifb:off` |
| Backlight | `intel_backlight` sysfs works; brightness keys still dead (OLED/HDR deep-research paused) |

Complete IOMMU reconnaissance is in `/home/agent-042/Documents/g16-bazzite-passthrough-inventory.md`.

## 2. What Is Done

- [x] Timezone default pushed: `feat/timezone-default` → `America/Chicago` image default.
- [x] Agent-context `#before(info)` header applied to AI-generated `.md`/`.txt` files in `/home/agent-042/Documents/` and `/var/roothome/`.
- [x] File permissions fixed on user documents (`agent-042:agent-042`, `644`).
- [x] libvirt isolated network created: `isolated-vm-net` (NAT 192.168.123.0/24).
- [x] Bazzite ISO download switched from single-thread (throttled ~700 KB/s) to 8-connection parallel chunked curl.
- [x] SHA256 checksum fetched for verification: `85e701c0f53189b0fa32797ffe8144202dcaa8db6c7692fd4677f615537b24b8`.

## 3. Current State

- ISO download: in progress (background task `bash-5totmygs`).
- Source: `https://download.bazzite.gg/bazzite-nvidia-open-stable-amd64.iso` (Cloudflare; GitHub releases do **not** host ISO assets).
- Checksum file: `/var/lib/libvirt/images/bazzite.iso-CHECKSUM`.
- Target ISO: `/var/lib/libvirt/images/bazzite.iso`.
- Download helper: `/var/lib/libvirt/images/download_bazzite.sh` (now downloads + verifies checksum).
- VM disk: not created yet.
- VM XML: not created yet.

## 4. Next Steps (in order)

1. Verify ISO checksum after parallel assembly completes.
2. `qemu-img create -f qcow2 /var/lib/libvirt/images/bazzite-vm.qcow2 100G`
3. Install Bazzite from ISO using `virt-install` with VNC/SPICE graphics and UEFI.
4. After installer shuts down VM, collect `/dev/input/by-id/` mouse + keyboard evdev names.
5. Build final VM XML with:
   - hostdev PCI `01:00.0` (GPU) and `01:00.1` (audio)
   - evdev mouse + keyboard passthrough
   - `<video><model type='none'/></video>`
   - kvmfr shared memory for Looking Glass
   - Hyper-V `vendor_id=NVKVMFIX`
6. Install/build `kvmfr` + `looking-glass-client` on host.
7. Start VM and verify `nvidia-smi` inside Bazzite.

## 5. Known Deviations From Original Human-Logic Sequence

- `~/SecureBlue-KDE-Agentic-Deploy/bazzite-deploy.sh` does not exist; equivalent steps done manually.
- `--graphics none` replaced with `--graphics vnc,listen=0.0.0.0` for interactive ISO install.
- Host reboots paused pending explicit approval; VM reboots during install are normal.

## 6. Relevant File Paths

| File | Purpose |
|------|---------|
| `/var/lib/libvirt/images/bazzite.iso` | Target ISO |
| `/var/lib/libvirt/images/bazzite.iso-CHECKSUM` | SHA256 checksum for verification |
| `/var/lib/libvirt/images/download_bazzite.sh` | Parallel downloader + verifier |
| `/home/agent-042/Documents/g16-bazzite-passthrough-inventory.md` | Full hardware reconnaissance |
| `/var/roothome/SecureBlue-KDE-Agentic-Deploy/.assets/docs/Agent_Context_Header_Standard.md` | Header standard guide |
| `/var/roothome/SecureBlue-KDE-Agentic-Deploy/.assets/docs/G16_Bazzite_VM_Handoff_BuildBlue_Pulse.md` | This file |

## 7. Blockers / Decisions For BuildBlue Pulse

- **Backlight fix**: paused. A separate deep-research prompt is being prepared.
- **Passthrough automation**: User requested a YOLO/Agent-Swarm bash script to automate IOMMU checks, VFIO binding, and libvirt XML patching without manual XML editing. Scope: after manual VM is proven working.
- **GitHub releases note**: User-supplied `curl -fLO https://github.com/ublue-os/bazzite/releases/latest/download/bazzite-kde-nvidia.iso` sequence is invalid because Bazzite GitHub releases only publish changelogs, not ISO assets. ISOs are served from `download.bazzite.gg`.
