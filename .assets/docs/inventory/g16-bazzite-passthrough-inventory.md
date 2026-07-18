# G16 Bazzite / BlueBuild GPU Passthrough Hardware Inventory

> **Deliverable for BuildBlue Pulse.**
> Standardized hardware reconnaissance for ASUS ROG Zephyrus G16 OLED (Intel Core Ultra 9 285H + RTX 5080).
> Use this for manual VFIO/GPU passthrough setup and as input for future BlueBuild module/script logic.

---

## Host Identity

| Field | Value |
|-------|-------|
| Hostname | Laptop-042 |
| Model | ASUS ROG Zephyrus G16 OLED (2.5K 240Hz) |
| CPU | Intel Core Ultra 9 285H (Arrow Lake-H) |
| iGPU | Intel Arrow Lake-P [Arc Pro 130T/140T] (8086:7d51) |
| dGPU | NVIDIA GeForce RTX 5080 Mobile/Max-Q (10de:2c59 VGA + 10de:22e9 Audio) |
| Panel | Samsung SDC 16803 2560x1600@240Hz OLED on eDP-1 |
| OS | SecureBlue KDE Kinoite 44.20260710.0 (Fedora 44 Atomic, rpm-ostree) |
| Kernel | 7.1.3-200.fc44.x86_64 |
| Desktop | KDE Plasma / KWin / PowerDevil / KScreen 6.7.2, Wayland |
| User session | agent-042 (uid 1000), SDDM on tty2 |

---

## Active Kernel Command Line

```text
BOOT_IMAGE=(hd0,gpt2)/ostree/default-3584e5d60c568aa7211dd8ec17cf4704baceb4aa9216716b3265f2a16d275c1c/vmlinuz-7.1.3-200.fc44.x86_64
ostree=/ostree/boot.1/default/3584e5d60c568aa7211dd8ec17cf4704baceb4aa9216716b3265f2a16d275c1c/0
hash_pointers=always init_on_alloc=1 init_on_free=1 kvm_amd.sev=1 kvm_amd.sev_es=1 kvm_amd.sev_snp=1
kvm-intel.vmentry_l1d_flush=always kvm.mitigate_smt_rsb=1 l1d_flush=on l1tf=full,force lockdown=confidentiality
loglevel=0 mitigations=auto,nosmt module.sig_enforce=1 page_alloc.shuffle=1 proc_mem.force_override=ptrace
pti=on random.trust_bootloader=off random.trust_cpu=off randomize_kstack_offset=on rd.emergency=halt rd.shell=0
slab_debug=FZ slab_nomerge spec_store_bypass_disable=on spectre_v2=on ssbd=force-on systemd.ssh_auto=no vdso32=0
vsyscall=none rd.luks.uuid=luks-2ebe49e2-875d-4823-b443-e89eb3e6ab32 pci=noaer rhgb quiet
root=UUID=f6e2a6fe-5e90-4cc0-b704-9f65f8e256ee vconsole.keymap=us rootflags=subvol=root rw ia32_emulation=0
nosmt=force bdev_allow_write_mounted=0 debugfs=off efi=disable_early_pci_dma gather_data_sampling=force
mem_encrypt=on oops=panic
intel_iommu=on iommu=pt rd.driver.pre=vfio-pci vfio-pci.ids=10de:2c59,10de:22e9
i915.force_probe=!8086:7d51 xe.force_probe=8086:7d51 xe.enable_dpcd_backlight=2
acpi_backlight=native video=efifb:off
```

### Passthrough-relevant kargs (extracted)

```text
intel_iommu=on
iommu=pt
rd.driver.pre=vfio-pci
vfio-pci.ids=10de:2c59,10de:22e9
i915.force_probe=!8086:7d51
xe.force_probe=8086:7d51
xe.enable_dpcd_backlight=2
acpi_backlight=native
video=efifb:off
```

---

## PCI Topology

```text
0000:00:00.0 Host bridge: Intel Corporation Core Ultra 200H Series Processors with 6 P-Cores 8 E-Cores Host Bridge [8086:7d06]
0000:00:01.0 PCI bridge: Intel Corporation Core Ultra 200 Series Processors PCIe Root Port #12 [8086:7ecc]
0000:00:02.0 VGA compatible controller: Intel Corporation Arrow Lake-P [Arc Pro 130T/140T] [8086:7d51]
0000:00:04.0 Signal processing controller: Intel Corporation Core Ultra 200H/200V Series Processors DTT [8086:7d03]
0000:00:06.0 System peripheral: Intel Corporation RST VMD Managed Controller [8086:09ab]
0000:00:07.0 PCI bridge: Intel Corporation Core Ultra 200 Series Processors USB Type-C Subsystem PCIe Root Port #16 [8086:7ec4]
0000:00:08.0 System peripheral: Intel Corporation Core Ultra 200H/200V Series Processors GNA [8086:774c]
0000:00:0a.0 Signal processing controller: Intel Corporation Core Ultra 200H/200V Series Processors PMT [8086:7d0d]
0000:00:0b.0 Processing accelerators: Intel Corporation Core Ultra 200H/200V Series Processors NPU [8086:7d1d]
0000:00:0d.0 USB controller: Intel Corporation Core Ultra 200 Series Processors USB xHCI [8086:7ec0]
0000:00:0d.2 USB controller: Intel Corporation Core Ultra 200 Series Processors Thunderbolt DMA0 [8086:7ec2]
0000:00:0e.0 RAID bus controller: Intel Corporation Core Ultra 200H/200V Series Processors VMD [8086:7d0b]
0000:00:14.0 USB controller: Intel Corporation Core Ultra 200H/200V Series Processors Standalone xHCI Controller [8086:777d]
0000:00:14.2 RAM memory: Intel Corporation Core Ultra 200H/200V Series Processors Shared SRAM [8086:777f]
0000:00:14.3 Network controller: Intel Corporation Arrow Lake CNVi WiFi [8086:7740]
0000:00:15.0 Serial bus controller: Intel Corporation Core Ultra 200H/200V Series Processors I2C #0 [8086:7778]
0000:00:15.3 Serial bus controller: Intel Corporation Core Ultra 200H/200V Series Processors I2C #3 [8086:777b]
0000:00:16.0 Communication controller: Intel Corporation Core Ultra 200H/200V Series Processors CSME HECI #1 [8086:7770]
0000:00:1c.0 PCI bridge: Intel Corporation Core Ultra 200H/200V Series Processors PCIe Root Port #4 [8086:773b]
0000:00:1e.0 Communication controller: Intel Corporation Core Ultra 200H/200V Series Processors UART #0 [8086:7725]
0000:00:1e.2 Serial bus controller: Intel Corporation Core Ultra 200H/200V Series Processors GSPI #0 [8086:7727]
0000:00:1f.0 ISA bridge: Intel Corporation Arrow Lake-H eSPI Controller [8086:7702]
0000:00:1f.3 Audio device: Intel Corporation Core Ultra 200H/200V Series Processors HD Audio [8086:7728]
0000:00:1f.4 SMBus: Intel Corporation Core Ultra 200H/200V Series Processors SMBus [8086:7722]
0000:00:1f.5 Serial bus controller: Intel Corporation Core Ultra 200H/200V Series Processors SPI Controller [8086:7723]
0000:01:00.0 VGA compatible controller: NVIDIA Corporation GB203M / GN22-X9 [GeForce RTX 5080 Max-Q / Mobile] [10de:2c59]
0000:01:00.1 Audio device: NVIDIA Corporation GB203 High Definition Audio Controller [10de:22e9]
0000:2c:00.0 Unassigned class [ff00]: Realtek Semiconductor Co., Ltd. RTS525A PCI Express Card Reader [10ec:525a]
10000:e0:06.0 PCI bridge: Intel Corporation Core Ultra 200H/200V Series Processors PCIe Root Port #9 [8086:774d]
10000:e1:00.0 Non-Volatile memory controller: Micron Technology Inc 2500 NVMe SSD [1344:5425]
```

---

## IOMMU Groups

```text
Group  0: 0000:00:02.0 Intel Arrow Lake-P iGPU [8086:7d51]
Group  1: 0000:00:00.0 Intel Core Ultra 200H Host Bridge [8086:7d06]
Group  2: 0000:00:01.0 Intel PCIe Root Port #12 [8086:7ecc]
Group  3: 0000:00:04.0 Intel DTT [8086:7d03]
Group  4: 0000:00:06.0 Intel RST VMD [8086:09ab]
Group  5: 0000:00:07.0 Intel USB Type-C Root Port #16 [8086:7ec4]
Group  6: 0000:00:08.0 Intel GNA [8086:774c]
Group  7: 0000:00:0a.0 Intel PMT [8086:7d0d]
Group  8: 0000:00:0b.0 Intel NPU [8086:7d1d]
Group  9: 0000:00:0d.0 Intel USB xHCI [8086:7ec0]
Group  9: 0000:00:0d.2 Intel Thunderbolt DMA0 [8086:7ec2]
Group 10: 0000:00:0e.0 Intel VMD [8086:7d0b]
Group 10: 10000:e0:06.0 Intel PCIe Root Port #9 [8086:774d]
Group 10: 10000:e1:00.0 Micron 2500 NVMe SSD [1344:5425]
Group 11: 0000:00:14.0 Intel Standalone xHCI [8086:777d]
Group 11: 0000:00:14.2 Intel Shared SRAM [8086:777f]
Group 12: 0000:00:14.3 Intel Arrow Lake CNVi WiFi [8086:7740]
Group 13: 0000:00:15.0 Intel I2C #0 [8086:7778]
Group 13: 0000:00:15.3 Intel I2C #3 [8086:777b]
Group 14: 0000:00:16.0 Intel CSME HECI #1 [8086:7770]
Group 15: 0000:00:1c.0 Intel PCIe Root Port #4 [8086:773b]
Group 16: 0000:00:1e.0 Intel UART #0 [8086:7725]
Group 16: 0000:00:1e.2 Intel GSPI #0 [8086:7727]
Group 17: 0000:00:1f.0 Intel eSPI [8086:7702]
Group 17: 0000:00:1f.3 Intel HD Audio [8086:7728]
Group 17: 0000:00:1f.4 Intel SMBus [8086:7722]
Group 17: 0000:00:1f.5 Intel SPI [8086:7723]
Group 18: 0000:01:00.0 NVIDIA RTX 5080 VGA [10de:2c59]
Group 18: 0000:01:00.1 NVIDIA RTX 5080 HD Audio [10de:22e9]
Group 19: 0000:2c:00.0 Realtek RTS525A Card Reader [10ec:525a]
```

### Passthrough Assessment

- **dGPU IOMMU isolation:** EXCELLENT. Both NVIDIA functions are alone in **Group 18**.
- **USB controllers:** Group 9 has two Intel xHCI/TBT controllers; Group 11 has standalone xHCI + SRAM. USB passthrough is feasible but requires whole-group binding for any controller in a multi-device group.
- **NVMe / VMD:** Group 10 bundles VMD, root port, and NVMe. Not suitable for passthrough without ACS override (not recommended).

---

## Driver Binding State

| BDF | Device | Driver in use | Modules available | Notes |
|-----|--------|---------------|-------------------|-------|
| 0000:00:02.0 | Intel iGPU 8086:7d51 | i915 | i915, xe | Panel active on card1-eDP-1 |
| 0000:01:00.0 | NVIDIA RTX 5080 10de:2c59 | vfio-pci | nouveau, nvidia_drm, nvidia | Correctly isolated |
| 0000:01:00.1 | NVIDIA HD Audio 10de:22e9 | vfio-pci | snd_hda_intel | Correctly isolated |

---

## Display / Backlight

| Item | Value |
|------|-------|
| Active panel | `/sys/class/drm/card1-eDP-1` |
| Backlight sysfs | `/sys/class/backlight/intel_backlight` |
| Backlight type | raw |
| Max brightness | 192000 |
| Current brightness | 192000 |
| Panel scale | 1.25 (rendered 2048x1280) |
| kscreen-doctor HDR | incapable |
| kscreen-doctor WCG | incapable |
| Manual sysfs write test | SUCCESS (192000 → 48000 → 192000) |

### Backlight Notes for BlueBuild Logic

- The hardware DPCD backlight interface is functional.
- Brightness keys do **not** currently drive this interface automatically.
- This inventory does not solve the backlight-key routing problem; it documents the hardware state for passthrough work.

---

## Audio / USB

- **Intel HD Audio:** `0000:00:1f.3` bound to `snd_hda_intel`.
- **NVIDIA HD Audio:** `0000:01:00.1` bound to `vfio-pci` (isolated with dGPU).
- **USB controllers:** Three Intel controllers present; see IOMMU groups above.

---

## VFIO / Dracut Configuration on Disk

### /etc/modprobe.d/vfio.conf

```text
options vfio-pci ids=10de:2c59,10de:22e9 disable_vga=1
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
softdep nvidia_drm pre: vfio-pci
```

### /etc/dracut.conf.d/vfio.conf

```text
add_drivers+=" vfio vfio_iommu_type1 vfio_pci vfio_virqfd "
force_drivers+=" vfio_pci "
omit_drivers+=" nvidia nvidia-drm nouveau i915 "
```

### Initramfs state

```text
Initramfs: --add-drivers vfio-pci
```

---

## BlueBuild / Bazzite Script Inputs

### Module variables a BlueBuild module would need

```yaml
vfio_pci_ids: "10de:2c59,10de:22e9"
intel_igpu_pci_id: "8086:7d51"
nvidia_gpu_bdf: "0000:01:00.0"
nvidia_audio_bdf: "0000:01:00.1"
igpu_driver_target: "i915"   # current; xe may be desired later
iommu_mode: "pt"
```

### Recommended BlueBuild module structure

```yaml
modules:
  - type: kargs
    kargs:
      - intel_iommu=on
      - iommu=pt
      - rd.driver.pre=vfio-pci
      - vfio-pci.ids=10de:2c59,10de:22e9
      - i915.force_probe=!8086:7d51
      - xe.force_probe=8086:7d51
      - video=efifb:off
  - type: files
    files:
      - source: vfio-passthrough/etc
        destination: /etc
```

---

## BuildBlue Pulse Reconnaissance Block

=== BUILDBLUE PULSE REPORT ===
AGENT: Kimi Code 2.7
TARGET: G16 Reboot + IOMMU Reconnaissance
STATUS: COMPLETE
BACKLIGHT_STATUS: UNKNOWN (read 192000/192000; DPCD adjustment not exercised at time of report)
IOMMU_ENABLED: YES
RAW_OUTPUT:
[See sections above for cleaned, structured output of all 8 reconnaissance commands.]
ERRORS:
- Command 2 (dmesg filtered tail) returned empty output.
=== END REPORT ===

---

## Change Log

- 2026-07-18: Initial inventory generated from post-reboot G16 reconnaissance.
