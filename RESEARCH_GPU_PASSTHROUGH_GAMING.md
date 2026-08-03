# Research Phase 2: GPU Passthrough & Bazzite Gaming VM

This document provides a comprehensive guide for creating a high-performance, GPU-accelerated gaming VM inside Qubes OS, specifically targeting an AMD Ryzen 7 7800X3D + NVIDIA RTX 4080 hardware configuration.

## 1. Core Architecture

The strategy relies on a dual-GPU setup to maintain `dom0` security while providing near bare-metal performance for the gaming VM.

-   **`dom0` (Host):** Will run exclusively on the **AMD Ryzen 7 7800X3D's integrated GPU (iGPU)**. This keeps the host environment stable and secure.
-   **Gaming VM (Guest):** A Standalone HVM will be granted exclusive control over the **NVIDIA RTX 4080**.
-   **Display & Input:**
    -   One monitor cable will be connected to the motherboard's video output for `dom0`.
    -   A second monitor cable will be connected to the RTX 4080 for the gaming VM.
    -   A dedicated secondary USB controller must be passed through to the gaming VM for low-latency mouse and keyboard input.

## 2. Phase 1: Motherboard UEFI/BIOS Configuration

Correct UEFI/BIOS settings are critical. The following are required for the AM5 platform:

-   **Enable Core Virtualization:**
    -   **SVM Mode (Secure Virtual Machine):** `Enabled`
    -   **IOMMU:** `Enabled`
-   **Set Primary Graphics Adapter:**
    -   **Initial Display Output:** `IGFX` (or `Integrated Graphics`). This forces `dom0` to use the iGPU.
-   **Enable PCIe Features:**
    -   **Above 4G Decoding:** `Enabled`
    -   **Resizable BAR (ReBAR):** `Disabled` (Recommended, as it can cause instability with Xen).
-   **Apply AM5/Ryzen 7000 Workarounds:**
    -   **XHCI Hand-off:** `Disabled` (Prevents system freezes when `sys-usb` starts).
    -   **SMT (Simultaneous Multi-Threading):** `Disabled` (Works around a Xen bug that causes NVMe hangs on boot).

## 3. Phase 2: `dom0` & GRUB Configuration

### 3.1. Mandatory Xen Boot Parameter

The Ryzen 7000 series requires a Xen boot parameter to avoid boot hangs.

1.  During boot, press **`e`** at the GRUB menu to edit the boot entry.
2.  Find the line starting with `multiboot2 /boot/xen...`
3.  Append `x2apic=false` to this line.
4.  Press **Ctrl+X** to boot.
5.  To make this permanent, add `x2apic=false` to the `GRUB_CMDLINE_XEN_DEFAULT` variable in `/etc/default/grub` inside `dom0` and run `sudo grub2-mkconfig -o /boot/efi/EFI/qubes/grub.cfg`.

### 3.2. Hide the NVIDIA GPU from `dom0`

1.  In a `dom0` terminal, find the PCI addresses for the RTX 4080 and its audio device:
    ```bash
    lspci -nn | grep -i nvidia
    # Example output:
    # 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD103 [GeForce RTX 4080] [10de:2804]
    # 01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22bd]
    ```
2.  Edit `/etc/default/grub` in `dom0` and add the PCI addresses to hide them:
    ```bash
    # Find GRUB_CMDLINE_LINUX and append rd.qubes.hide_pci
    GRUB_CMDLINE_LINUX="... rd.qubes.hide_pci=01:00.0,01:00.1"
    ```
3.  Regenerate the GRUB config (`sudo grub2-mkconfig ...`) and reboot.
4.  Verify the GPU is using `pciback`: `lspci -k -s 01:00.0` should show `Kernel driver in use: pciback`.

## 4. Phase 3: Bazzite Standalone HVM Creation & Installation

1.  **Create StandaloneVM:** Create a new StandaloneVM named `bazzite-gaming`.
    ```bash
    qvm-create --class StandaloneVM --label red bazzite-gaming
    ```
2.  **Configure VM Preferences:**
    -   Set Virtualization mode to **HVM**.
    -   Set Memory to a static **16384 MB** (or more) and disable memory balancing.
    -   Set vCPUs to a high count (e.g., 8 or 12).
    -   Set Kernel to **(none)**.
    -   Increase the Private volume size to at least 100GB: `qvm-volume extend bazzite-gaming:private 100G`.
3.  **Install Bazzite:**
    -   Download the Bazzite NVIDIA ISO in a downloader AppVM.
    -   Copy the ISO to `dom0`: `qvm-run -p dl-vm 'cat /path/to/bazzite.iso' > /var/tmp/bazzite.iso`.
    -   Start the VM with the ISO attached: `qvm-start bazzite-gaming --cdrom=dom0:/var/tmp/bazzite.iso`.
    -   Follow the on-screen installer inside the VM window.
    -   Shut down the VM when installation is complete.

## 5. Phase 4: PCI Device Passthrough

1.  **Attach GPU & Audio:** In `dom0`, attach the GPU and its audio device to the VM.
    ```bash
    qvm-pci attach --persistent bazzite-gaming dom0:01_00.0
    qvm-pci attach --persistent bazzite-gaming dom0:01_00.1
    ```
2.  **Attach USB Controller:**
    -   Find the PCI address of a secondary USB controller using `lspci`.
    -   Hide it from `dom0` using `rd.qubes.hide_pci` (requires another reboot).
    -   Attach it to the VM: `qvm-pci attach --persistent bazzite-gaming dom0:XX_XX.X`.
3.  **Enable `no-strict-reset` (if needed):** If the VM fails to reboot cleanly, you may need to enable the `no-strict-reset` option for the GPU attachment.
    ```bash
    qvm-pci attach --persistent --option no-strict-reset=True bazzite-gaming dom0:01_00.0
    ```

## 6. Phase 5: Final Boot & Configuration

1.  Connect your gaming peripherals (mouse, keyboard) to the ports of the passed-through USB controller.
2.  Switch your monitor's input to the port connected to the RTX 4080.
3.  Start the VM: `qvm-start bazzite-gaming`.
4.  The Bazzite desktop should appear on your monitor.
5.  Complete the Bazzite first-time setup, which will install drivers, Steam, and other gaming utilities.
