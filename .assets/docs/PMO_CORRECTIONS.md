# Google AI Studio — Correction Directive
# BuildBlue Pulse PMO → Google AI Studio
# Last Updated: 2026-07-19 03:20 CST
# Source: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/pmo/corrections/.assets/docs/PMO_CORRECTIONS.md

## READ THIS FIRST

You are receiving this because BuildBlue Pulse (PMO) detected errors in your
previous Bazzite passthrough output. This document contains the exact corrections
you must apply before generating any further code for this repository.

**Constitution:** https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/main/.assets/docs/SPDM_CONSTITUTION.md  
**Baseline:** https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/main/.assets/docs/CONTRIBUTING_Coding_Agent.md  
**G16 Inventory:** https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/feat/bazzite-vm-scaffold/.assets/docs/inventory/g16-bazzite-passthrough-inventory.md  
**Current Scaffold:** https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/feat/bazzite-vm-scaffold/bazzite-deploy.sh  

---

## CRITICAL ERRORS (Will Break VM If Committed)

### 1. OVMF Firmware Path
**Your output:** `/usr/share/OVMF/OVMF_CODE_4M.fd`  
**Correct:** `/usr/share/edk2/ovmf/OVMF_CODE.fd`  
**Why:** Fedora/SecureBlue packages OVMF under `edk2/ovmf/`. The path you used is Debian/Ubuntu-specific.

### 2. Missing `<video><model type='none'/></video>`
**Your output:** No `<video>` tag in devices section  
**Correct:** Must include `<video><model type='none'/></video>`  
**Why:** Without this, QEMU creates a virtual VGA that conflicts with the passthrough dGPU. The VM will show a black screen.

### 3. kvmfr As Kernel Argument
**Your output:** `kvmfr.static_size_mb=128` in `rpm-ostree kargs`  
**Correct:** `modprobe kvmfr static_size_mb=128` + dracut config  
**Why:** `kvmfr` is a kernel **module parameter**, not a boot argument. Setting it as a karg silently fails.

### 4. CPU Topology Wrong
**Your output:** `cores='8' threads='1'` (claims 8 P-cores)  
**Correct:** `cores='4' threads='2'` (8 vCPU total, leaving host headroom)  
**Why:** Core Ultra 9 285H is 6P+8E. The VM does not get all P-cores. Use 4 cores × 2 threads = 8 vCPU.

### 5. Host Kernel Arguments Missing
**Your output:** Missing critical kargs  
**Correct:** Must include ALL of these for G16 host stability:
```
intel_iommu=on
iommu=pt
rd.driver.pre=vfio-pci
vfio-pci.ids=10de:2c59,10de:22e9
video=efifb:off
i915.force_probe=!8086:7d51
xe.force_probe=8086:7d51
```
**Why:** `video=efifb:off` prevents host from grabbing dGPU framebuffer. `i915/xe.force_probe` ensures iGPU stays active for host display.

### 6. QEMU `qemu.conf` ACL Edits
**Your output:** Modified `cgroup_device_acl` to add `/dev/kvmfr0`  
**Correct:** Do NOT touch `/etc/libvirt/qemu.conf`  
**Why:** Modern libvirt handles device access via the XML `<shmem>` device. Manual ACL edits are legacy and unnecessary on Fedora 44.

### 7. Udev Rules for kvmfr
**Your output:** Created `/etc/udev/rules.d/99-kvmfr.rules`  
**Correct:** Not needed  
**Why:** libvirt sets permissions on `/dev/kvmfr0` automatically when the `<shmem>` device is defined in the VM XML.

---

## MODERATE ERRORS (Quality Issues)

### 8. YubiKey Hotplug
**Your output:** Invented `pass-yubi`/`return-yubi` ujust aliases  
**Correct:** Remove entirely  
**Why:** YubiKey passthrough was never requested. Do not add features outside scope without human approval.

### 9. No ISO Install Steps
**Your output:** Runbook assumes VM is pre-installed  
**Correct:** Must include download + `virt-install --cdrom` sequence  
**Why:** The human needs to install Bazzite from ISO before the passthrough XML is relevant.

### 10. No Evdev Discovery
**Your output:** Placeholder `YOUR_KBD`/`YOUR_MOUSE` with no instructions  
**Correct:** Tell user to run `ls /dev/input/by-id/` and fill in values  
**Why:** Without real device IDs, evdev passthrough fails silently.

### 11. No Verification Step
**Your output:** No `nvidia-smi` check  
**Correct:** Final step must verify GPU is visible inside VM  
**Why:** Without verification, the user doesn't know if passthrough actually worked.

### 12. `GenuineIntel` vs `NVKVMFIX`
**Your output:** `vendor_id state='on' value='GenuineIntel'`  
**Correct:** `vendor_id state='on' value='NVKVMFIX'`  
**Why:** `GenuineIntel` is for AMD GPU spoofing. NVIDIA requires `NVKVMFIX` (or any non-NVIDIA string).

---

## AGENT HIERARCHY

```
HUMAN (Agent-042) — Final authority, merge approvals
    └── BuildBlue Pulse (PMO) — You are here
            └── Google AI Studio (Project Manager — Burst Implementation)
                    ├── Kimi Code 2.7 (G16 Endpoint Agent)
                    └── Antigriguity CLI (AMD Workstation Endpoint Agent)
```

**Your role:** You receive burst tasks from the human via PMO. You direct endpoint agents via metaprompts. You do NOT commit code with errors.

**If an endpoint agent goes off-rails:** PMO will tell you which agent, which error, and the exact correction. You reformulate the metaprompt and redelegate.

---

## WHAT YOU MUST DO NOW

1. Read the **Current Scaffold** (`bazzite-deploy.sh` on `feat/bazzite-vm-scaffold`) to see the correct patterns
2. Read the **G16 Inventory** for exact PCI IDs and IOMMU groups
3. Regenerate any Bazzite documentation using ONLY the correct values above
4. Do NOT invent features (YubiKey, etc.) without explicit human approval
5. Include verification steps (`nvidia-smi`) in every passthrough workflow

**If you are unsure about a hardware-specific value, STOP and ask PMO rather than guessing.**

---

## VERIFICATION CHECKLIST

Before committing any Bazzite-related code, verify:
- [ ] OVMF path is `/usr/share/edk2/ovmf/OVMF_CODE.fd`
- [ ] `<video><model type='none'/></video>` is present
- [ ] kvmfr is loaded via `modprobe`, not kernel arg
- [ ] CPU topology uses 4 cores × 2 threads (not 8 P-cores)
- [ ] `video=efifb:off` is in host kargs
- [ ] No `qemu.conf` modifications
- [ ] No udev rules for kvmfr
- [ ] No out-of-scope features (YubiKey, etc.)
- [ ] Evdev discovery instructions included
- [ ] `nvidia-smi` verification step included
- [ ] `vendor_id` is `NVKVMFIX`, not `GenuineIntel`

---

*This document is maintained by BuildBlue Pulse PMO. Updates are pushed to the
`pmo/corrections` branch. Do not edit without PMO approval.*
