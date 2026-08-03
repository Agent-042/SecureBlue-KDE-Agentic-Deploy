# Research: Nested Virtualization of Qubes OS on KVM

This document details the feasibility, process, and limitations of running Qubes OS as a nested Level 1 (L1) guest hypervisor on top of a Level 0 (L0) KVM host, such as a SecureBlue workstation.

## 1. Executive Summary

-   **Is it Possible?** **Yes.** With specific configuration, Qubes OS can be installed and run inside a KVM virtual machine. This is primarily useful for development, CI/CD, and testing automation without dedicated hardware.
-   **Is it Recommended for Production?** **No.** This configuration is experimental, carries a significant performance penalty, and fundamentally reduces the security guarantees that Qubes OS provides on bare metal.
-   **Can it be used for GPU Passthrough?** **No.** Nested PCI passthrough (L0 Host -> L1 Guest -> L2 VM) is not a practical or supported configuration. This setup is unsuitable for the high-performance gaming VM blueprint.

## 2. Architectural Overview

This setup involves two layers of virtualization:

-   **L0 Host (SecureBlue):** The bare-metal machine running a standard Linux kernel with KVM.
-   **L1 Guest (Qubes VM):** A KVM virtual machine running the entire Qubes OS stack, including its own Xen hypervisor.
-   **L2 Guests (AppVMs):** The AppVMs (e.g., `sys-net`, `work`) running inside the nested Qubes OS instance.

For this to work, the L0 hypervisor (KVM) must be able to expose hardware virtualization extensions (`AMD-V`) and an emulated IOMMU down to the L1 guest (Xen).

## 3. Step 1: Host (SecureBlue) Configuration

The SecureBlue host must be prepared for nested virtualization.

### 3.1. Enable Nested Virtualization in KVM

1.  **Check Status:** Verify if nesting is already enabled for your CPU.
    ```bash
    cat /sys/module/kvm_amd/parameters/nested
    ```
    If the output is `1` or `Y`, you can skip to the next step.

2.  **Enable Permanently:** If disabled, create a modprobe configuration file.
    ```bash
    echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm_nested.conf
    ```

3.  **Reboot** the host or reload the kernel modules for the change to take effect.
    ```bash
    sudo modprobe -r kvm_amd && sudo modprobe kvm_amd
    ```

### 3.2. Install Virtualization Packages

SecureBlue is minimal and does not include virtualization tools by default. They must be layered with `rpm-ostree`.

```bash
rpm-ostree install libvirt qemu-kvm virt-install virt-manager
systemctl reboot
```

After rebooting, add your user to the `libvirt` group: `sudo usermod -aG libvirt $USER`.

## 4. Step 2: Guest (Qubes VM) Configuration

This is the most critical part. The libvirt XML for the Qubes OS VM must be manually edited to include the necessary features.

1.  **Create a placeholder VM** using `virt-manager` or `virt-install`. Use the Qubes OS ISO and select a Fedora profile. Allocate at least **4 vCPUs** and **16GB of RAM**.

2.  **Edit the XML:** Open the VM settings in `virt-manager` and switch to the XML tab, or use `virsh edit <vm-name>`. Make the following changes:

    a. **Set CPU to `host-passthrough`:** This exposes the `svm` (AMD-V) flag to the guest.

    ```xml
    <cpu mode="host-passthrough" check="none" migratable="on"/>
    ```

    b. **Set Machine Type to `q35`:** The default `pc` type is not sufficient. Find the `<os>` block and change the machine type.

    ```xml
    <os>
      <type arch='x86_64' machine='pc-q35-8.1'>hvm</type>
      ...
    </os>
    ```

    c. **Add an Emulated Intel IOMMU:** Qubes requires an IOMMU. KVM can provide a virtual one. Add this inside the `<devices>` block.

    ```xml
    <devices>
      ...
      <iommu model='intel'>
        <driver intremap='on' caching_mode='on'/>
      </iommu>
      ...
    </devices>
    ```

    d. **Set the IOAPIC driver:** Inside the `<features>` block, add the following line.

    ```xml
    <features>
      ...
      <ioapic driver='qemu'/>
    </features>
    ```

3.  **Save the configuration.** The VM is now ready for installation.

## 5. Step 3: Installation and First Boot

1.  **Boot the VM** from the Qubes OS ISO.
2.  Proceed with the standard Qubes OS installation. The installer should now detect the virtualized hardware and IOMMU correctly.
3.  **First Boot and HVMs:** Upon first boot, the nested Qubes OS will be able to create its own HVMs (L2 guests), as Xen (L1) now has access to the nested hardware virtualization features provided by KVM (L0).

## 6. Performance and Limitations

-   **CPU Overhead:** Expect significant slowdowns on CPU-intensive tasks. Every privileged instruction from an L2 AppVM has to be trapped by L1 Xen, then re-trapped and emulated by L0 KVM.
-   **I/O Performance:** Disk and network throughput will be substantially lower than on bare metal.
-   **No Live Migration/Save:** The L1 Qubes VM cannot be safely saved, paused, or live-migrated once it has started its own L2 AppVMs.
-   **Reduced Security:** The primary security benefit of Qubes is Xen's direct control over the hardware. By introducing KVM as another hypervisor layer, you add a massive new attack surface between Qubes and the physical hardware. **This configuration is not suitable for any security-critical work.**
