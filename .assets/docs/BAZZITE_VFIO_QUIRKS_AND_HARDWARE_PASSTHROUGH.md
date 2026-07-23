# Bazzite VM Passthrough Quirks & Hardware Passthrough Reference

> **PURPOSE**: Comprehensive documentation of hardware passthrough quirks, SVM/IOMMU configuration, secondary GPU dynamic binding, and Bazzite OS container/VM execution on SecureBlue Kinoite.

---

## 1. Hardware Topology & Passthrough Layout

```
Host CPU           : AMD Ryzen 7 7800X3D (8 Cores / 16 Threads)
Host Motherboard   : Gigabyte B650 AORUS ELITE AX
Primary Display GPU: AMD Radeon iGPU (Mesa / RADV driver) -> Desktop Wayland display
Secondary Gaming GPU: NVIDIA GeForce RTX 4080 (16GB VRAM) -> Dedicated VFIO Passthrough
```

---

## 2. SVM & IOMMU Grouping Quirks

1. **AMD SVM Enablement**:
   SVM (Secure Virtual Machine) must be enabled in the Gigabyte BIOS under `Advanced CPU Settings -> SVM Mode -> Enabled`.
2. **Kernel Arguments**:
   ```bash
   amd_iommu=on iommu=pt
   ```
   `iommu=pt` (pass-through) prevents performance degradation on DMA translations for non-passed-through devices.
3. **IOMMU Group Isolation**:
   The RTX 4080 (01:00.0) and its companion HDA Audio controller (01:00.1) reside in their own isolated IOMMU group on B650 chipset PCIe 5.0 slot 1, requiring no ACS override kernel patches.

---

## 3. Dynamic Secondary GPU Unbinding / Rebinding

To allow the host system to run quietly when gaming is inactive, the RTX 4080 is dynamically rebound to `vfio-pci` before launching the Bazzite VM, and can be restored afterwards.

### Dynamic Binding Script (`vfio-bind-secondary-gpu.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail

GPU_PCI="0000:01:00.0"
AUDIO_PCI="0000:01:00.1"

echo "[VFIO] Unbinding NVIDIA RTX 4080 from host driver..."
echo "$GPU_PCI" > /sys/bus/pci/devices/$GPU_PCI/driver/unbind 2>/dev/null || true
echo "$AUDIO_PCI" > /sys/bus/pci/devices/$AUDIO_PCI/driver/unbind 2>/dev/null || true

echo "[VFIO] Binding $GPU_PCI and $AUDIO_PCI to vfio-pci..."
echo "10de 2704" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
echo "10de 22bb" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true

echo "$GPU_PCI" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
echo "$AUDIO_PCI" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true

echo "[SUCCESS] RTX 4080 bound to vfio-pci."
```

---

## 4. Libvirt VM Configuration Quirks (`bazzite-gaming-passthrough.xml`)

Key libvirt XML quirks required for Bazzite OS under KVM:

1. **Vendor ID Hiding (NVIDIA driver error 43 workaround)**:
   ```xml
   <kvm>
     <hidden state='on'/>
   </kvm>
   ```
2. **Host CPU Pass-through with SVM extension**:
   ```xml
   <cpu mode='host-passthrough' check='none'>
     <topology sockets='1' dies='1' cores='8' threads='2'/>
     <feature policy='require' name='svm'/>
   </cpu>
   ```
3. **Direct Host PCIe Device Allocation**:
   ```xml
   <hostdev mode='subsystem' type='pci' managed='yes'>
     <source>
       <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
     </source>
   </hostdev>
   ```

---

## 5. Audio & PipeWire Integration

PipeWire audio from the VM is passed back to the host audio graph using PipeWire Virtual Sink or direct ALSA loopback managed by `pipewire_capture_agent.py`.
