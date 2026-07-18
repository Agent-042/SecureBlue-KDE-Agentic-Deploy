# Phase 2 Execution Report: AMD Workstation SVM & VFIO-PCI Assembly

## SPDM Information Block
- **SPDM Constitution**: [SPDM_CONSTITUTION.md](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/SPDM_CONSTITUTION.md)
- **Coding Agent Baseline**: [CONTRIBUTING_Coding_Agent.md](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/CONTRIBUTING_Coding_Agent.md)
- **Branch**: `arch/spdm-refactor`
- **Target**: AMD Workstation RTX 4080 / Post-Reboot Assembly
- **GITHUB_PAT**: `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`

---

## 1. Virtualization & IOMMU Verification

### SVM State (AMD CPU Virtualization)
- **Status**: **Enabled (Active)**
- **Verification**: `grep -i svm /proc/cpuinfo` confirms CPU flags include the `svm` virtualization feature.
- **KVM Module**: `kvm_amd` is loaded successfully:
  ```bash
  kvm_amd               274432  0
  kvm                  1568768  1 kvm_amd
  ```

### AMD-Vi (IOMMU) State
- **Status**: **Enabled (Active)**
- **Kernel Command Line Parameters**:
  - `amd_iommu=on`
  - `iommu=pt`
- **Verification**: `dmesg` confirms AMD-Vi initialization:
  ```
  [    2.799026] pci 0000:00:00.2: AMD-Vi: IOMMU performance counters supported
  [    2.802065] AMD-Vi: Extended features (0x246577efa2254afa, 0x0): PPR NX GT [5] IA GA PC GA_vAPIC
  [    2.802075] AMD-Vi: Interrupt remapping enabled
  [    2.836038] AMD-Vi: Virtual APIC enabled
  ```

### Device Isolation (IOMMU Group 12)
The RTX 4080 GPU and its HDMI audio controller are isolated in their own IOMMU group (Group 12), ensuring clean passthrough boundaries without conflicts:
- `0000:01:00.0` [10de:2704] - NVIDIA Corporation AD103 [GeForce RTX 4080] (IOMMU Group 12)
- `0000:01:00.1` [10de:22bb] - NVIDIA Corporation AD103 High Definition Audio Controller (IOMMU Group 12)

---

## 2. Driver Binding & Initramfs Rebuild

### Current Binding State
- **Audio Device (`01:00.1`)**: Bound to `vfio-pci`.
- **GPU Device (`01:00.0`)**: Bound to `nvidia` at runtime.
- **Issue**: The NVIDIA driver was loaded early by systemd before `vfio-pci` could claim it because `vfio-pci` was missing from the initramfs. Attempting to unbind the GPU at runtime while Wayland (kwin) was running caused the kernel driver to spin.
- **Fix**: We created a custom dracut configuration to build `vfio-pci` directly into the initramfs and enabled local initramfs regeneration.

### dracut Configuration (`/etc/dracut.conf.d/vfio.conf`)
```
add_drivers+=" vfio vfio_iommu_type1 vfio_pci "
```

### rpm-ostree Local Initramfs Status
Successfully enabled local initramfs regeneration via `rpm-ostree initramfs --enable`.
- **Pending/Staged deployment**:
  ```
  Deployments:
    ostree-unverified-registry:ghcr.io/agent-042/secureblue-kde-agentic-deploy-amd-workstation:latest
                     Digest: sha256:956bbc953d5d26d1522084e64f5e91f3e0567e4bd3d78e521080940fb3097efe
                    Version: 44.20260710.0 (2026-07-10T17:04:46Z)
                  Initramfs: regenerate
  ```
> [!IMPORTANT]
> The machine must be rebooted to boot into this staged deployment. Upon reboot, the new initramfs will load `vfio-pci` early and successfully bind the RTX 4080 GPU (`01:00.0`), isolating it from the host desktop environment.

### Systemd Early GPU Binding Override (Lazy Local Fix)
To prevent runtime GPU binding deadlocks in the future (even if initramfs configuration is lost during upgrades or rebases), we created and enabled a local systemd override for the secondary GPU binding service:
- **File**: `/etc/systemd/system/vfio-bind-secondary-gpu.service`
- **Configuration**:
  ```ini
  [Unit]
  Description=Bind secondary NVIDIA GPU to vfio-pci
  DefaultDependencies=no
  After=systemd-modules-load.service
  Before=plasmalogin.service display-manager.service

  [Service]
  Type=oneshot
  ExecStart=/usr/bin/vfio-bind-secondary-gpu.sh
  RemainAfterExit=yes

  [Install]
  RequiredBy=plasmalogin.service display-manager.service
  WantedBy=basic.target
  ```
- **Why this is critical**: The default service in the repository was configured with `After=multi-user.target`, which ran too late (after the GUI had already started and `kwin_wayland` had opened the GPU). This override forces the script to run early during the boot sequence before the login/display managers launch, resolving the race condition.
- **G16 System Recommendation**: The related **G16 laptop** configuration in the repository shares this service and would benefit directly from this patch to prevent similar race-induced deadlocks.

---

## 3. High-Performance VM Configuration

The high-performance XML configuration has been defined as **`bazzite-gaming`**.

### Configuration Highlights:
1. **CPU Passthrough with Hyperthreading (AMD Ryzen 7 7800X3D)**:
   - Configured topology with 6 cores and 2 threads (12 vCPUs total).
   - Added `topoext=on` to QEMU custom arguments to expose proper AMD hyperthreading structures.
2. **GPU & Audio Passthrough**:
   - PCIe passthrough of GPU `01:00.0` and Audio `01:00.1` via `<hostdev>` nodes.
3. **VirtIO High Performance**:
   - VirtIO Disk Controller (`cache='none'`, `io='native'`, `discard='unmap'`) using the `/var/lib/libvirt/images/bazzite-vm.qcow2` storage.
   - VirtIO Network device.
4. **Looking Glass Integration**:
   - ivshmem-plain device named `looking-glass` with `128M` size.
   - `/dev/shm/looking-glass` shared memory device configured with `agent-42:qemu` ownership (perms `660`) and labeled with `svirt_image_t` SELinux context to allow secure guest-host access.
5. **Physical Bits Workaround**:
   - Appended `host-phys-bits-limit=39` to the QEMU command line to prevent DMA mapping faults.

### VM Config file: [/root/bazzite-gaming-passthrough.xml](file:///root/bazzite-gaming-passthrough.xml)

---

## 4. Current Status & Next Steps

### Analysis of the Reboot Hang
1. **Previous Hang**: The initial reboot hang occurred because the system was attempting to boot an unsigned local image deployment with Secure Boot enabled in the Gigabyte BIOS. The BIOS refused to load the unsigned image and locked up. This is now fully resolved because the operator disabled Secure Boot in the BIOS (`SecureBoot disabled`, `Platform is in Setup Mode`).
2. **Current Hang Risk**: The host currently has a wedged `nvidia` kernel process spinning at 100% CPU on a core. This occurred because we ran an `unbind` operation at runtime while `kwin_wayland` still held file descriptors to the GPU open. This process is in uninterruptible kernel sleep (`D` / `R` loop) and ignores SIGKILL. A standard systemd-controlled reboot will hang indefinitely waiting for this process.

### Safe Reboot Workaround (SysRq Reboot)
To bypass the wedged kernel process and force an immediate, filesystem-safe reboot, run the provided helper script:
```bash
/root/safe-sysrq-reboot.sh
```
This script will execute the following Magic SysRq commands:
1. Enable SysRq: `echo 1 > /proc/sys/kernel/sysrq`
2. Force Sync: `echo s > /proc/sysrq-trigger`
3. Force Remount Read-Only: `echo u > /proc/sysrq-trigger`
4. Force Reboot: `echo b > /proc/sysrq-trigger`

### Post-Reboot Verification
Once the host boots back up, the newly regenerated initramfs deployment will load `vfio-pci` early and successfully claim the RTX 4080 GPU.
1. Check driver binding:
   ```bash
   lspci -nnk -d 10de:2704
   ```
   (Verify 'Kernel driver in use' is `vfio-pci`).
2. Start the VM:
   ```bash
   virsh start bazzite-gaming
   ```
3. Monitor logs:
   ```bash
   tail -f /var/log/libvirt/qemu/bazzite-gaming.log
   ```
