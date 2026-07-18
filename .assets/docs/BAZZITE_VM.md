# Bazzite VM Deployment and Provisioning Guide

This guide details how to configure, provision, and run a high-performance Bazzite gaming VM inside SecureBlue using GPU and audio passthrough, Looking Glass, and evdev input routing.

## Prerequisites

To achieve near-native performance for gaming, ensure your host has the following configured:

1. **IOMMU and Virtualization Enabled:**
   - AMD: Enable `SVM` (Virtualization) and `IOMMU` in UEFI.
   - Intel: Enable `Intel Virtualization Technology (VT-x)` and `VT-d` in UEFI.
   - Kernel arguments in SecureBlue should already include `amd_iommu=on iommu=pt` or `intel_iommu=on iommu=pt`.

2. **VFIO-PCI Drivers:**
   - Ensure the target GPU and secondary audio controllers are bound to `vfio-pci` at boot.
   - Use the built-in udev/initramfs mechanics or `/etc/modprobe.d/vfio.conf` to bind the PCI IDs.

3. **Looking Glass Host Setup:**
   - Install the Looking Glass client tool on the host (`looking-glass-client`).
   - Create a shared memory file `/dev/shm/looking-glass` with correct group permissions (`kvm` group read/write).

---

## Hardware Reconnaissance: Finding PCI IDs

Before defining the VM, you must identify your GPU and audio controller PCI addresses.

### 1. Identify the GPU and GPU-Audio controllers:
Run the following command to find your GPU PCI addresses:
```bash
lspci -nn | grep -i -E "vga|3d|audio"
```
Example Output:
```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD104 [GeForce RTX 4070] [10de:2786] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22bc] (rev a1)
```

In this case:
- GPU Bus: `01`, Slot: `00`, Function: `0` (`0000:01:00.0`)
- GPU Audio Bus: `01`, Slot: `00`, Function: `1` (`0000:01:00.1`)

### 2. Identify the Guest Audio Controller (if separating host/guest):
Find any dedicated onboard sound card or USB host controller you want to pass to the VM:
```bash
lspci -nn | grep -i audio
```
Identify the bus, slot, and function.

### 3. Update the placeholders in `bazzite-deploy.sh`:
Before executing `bazzite-deploy.sh`, edit the script or the VM XML to replace:
- `PLACEHOLDER_GPU_BUS`
- `PLACEHOLDER_GPU_SLOT`
- `PLACEHOLDER_AUDIO_BUS`
- `PLACEHOLDER_AUDIO_SLOT`
- `PLACEHOLDER_AUDIO_FUNCTION`
- `PLACEHOLDER_MOUSE_ID` (from `/dev/input/by-id/`)
- `PLACEHOLDER_KEYBOARD_ID` (from `/dev/input/by-id/`)

---

## VM Provisioning and Deployment

To deploy the VM scaffold and configure isolated networking:

1. Edit the placeholders in `bazzite-deploy.sh`.
2. Run the deployment script with root escalation:
   ```bash
   run0 bash bazzite-deploy.sh
   ```

The script will automatically:
- Install the VM/virtualization tools.
- Configure isolated firewalld zones for safe networking.
- Generate the VM domain XML template.
- Register/define the VM with `virsh`.

---

## Launching the VM and Client

1. **Start the VM:**
   ```bash
   virsh start bazzite-vm
   ```
2. **Launch Looking Glass Client:**
   Ensure your guest Bazzite OS has the Looking Glass host application installed and running, then start the client:
   ```bash
   looking-glass-client
   ```

Alternatively, use the desktop shortcut launcher:
- Click the **Bazzite VM Launcher** from your desktop or Application Launcher.

---

## Input Switching: Evdev Hotkey Toggle

We configure QEMU's native `input-linux` driver (evdev) for latency-free keyboard and mouse routing. 

- **How it works:** QEMU directly captures inputs from `/dev/input/by-id/` devices.
- **Toggling inputs:** Press both **Left Ctrl** and **Right Ctrl** keys simultaneously to release your mouse and keyboard control back to the host system. Pressing it again passes control back to the guest Bazzite VM.
