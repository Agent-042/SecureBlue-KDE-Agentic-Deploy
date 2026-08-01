# DEEP RESEARCH METAPROMPT: NATIVE QUBES OS TYPE-1 HYPERVISOR VIRTUALIZATION ON KVM/QEMU

> **Target Architecture**: Qubes OS R4.3.1 (Xen 4.19+ / Linux 6.12+ Dom0)  
> **Host Operating System**: SecureBlue / Bazzite / Fedora Atomic KVM  
> **Hypervisor Strategy**: QEMU/KVM Nested Virtualization with Hardware Passthrough & Custom GRUB Parameters  
> **GitHub Repository**: [`Agent-042/SecureBlue-KDE-Agentic-Deploy`](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy)  

---

```
                       ┌────────────────────────────────────────────────────────┐
                       │     QUBES OS KVM NESTED VIRTUALIZATION PIPELINE        │
                       └───────────────────────────┬────────────────────────────┘
                                                   │
     ┌─────────────────────────────────────────────┴─────────────────────────────────────────────┐
     ▼                                                                                           ▼
┌────────────────────────────────────────┐                                     ┌────────────────────────────────────────┐
│ 1. EDK2 / OVMF FIRMWARE HANDOFF        │                                     │ 2. XEN HYPERVISOR & KERNEL CMDLINE     │
│ - Non-SecureBoot OVMF_CODE_4M.qcow2    │                                     │ - Strip "quiet" from GRUB module2      │
│ - Bypass PageFaultExitBoot NX Faults   │                                     │ - Add "nomodeset vga=current"          │
│ - 64MB VGA VBE Framebuffer Video Model │                                     │ - Enable console=vga & Xen debug log   │
└──────────────────┬─────────────────────┘                                     └──────────────────┬─────────────────────┘
                   │                                                                              │
                   └───────────────────────────────┬──────────────────────────────────────────────┘
                                                   │
                                                   ▼
                       ┌────────────────────────────────────────────────────────┐
                       │ 3. NESTED HARDWARE PASSTHROUGH & DOM0 DESKTOP          │
                       │ - host-passthrough CPU with VMX/SVM required          │
                       │ - Looking Glass IVSHMEM Frame Buffer Capture           │
                       │ - Full Xfce/Plasma Dom0 Desktop Rendering             │
                       └────────────────────────────────────────────────────────┘
```

---

## 1. Empirical Screenshot Error Log & Traceback Analysis

During live execution and GUI inspection of `qubes-agentic-powerhouse` and `qubes-vm`, the following empirical errors were observed and documented:

### Error 1: EDK2 OVMF SecureBoot Memory Policy Violation
* **Screenshot Artifact**: [`qubes_dom0_xen_proof.png`](file:///root/.gemini/antigravity-cli/brain/2f00e452-11f9-4327-a0f0-4900f5dcc21b/qubes_dom0_xen_proof.png)
* **Exact Log Traceback**:
  ```text
  PageFaultExitBoot: Page fault fixups needed (NX: 3, RW: 0).
  PageFaultExitBoot: The guest OS boot chain is not NX clean.
  PageFaultExitBoot: Applying global page table fixup (saw NX faults).
  ```
* **Root Cause Analysis**: Modern EDK2/OVMF firmware with Secure Boot enabled enforces strict No-Execute (NX) memory protections. The Xen 4.19 EFI bootloader initializes writable memory regions that violate NX policies, causing EDK2 to trigger page fault fixups and halt execution.
* **Resolution**: Replace `OVMF_CODE_4M.secboot.qcow2` with standard non-SecureBoot `OVMF_CODE_4M.qcow2` and disable `<feature enabled='no' name='secure-boot'/>`.

### Error 2: Kernel Mode Setting (KMS) & Black Screen Freeze
* **Screenshot Artifact**: [`qubes_dom0_clean_ovmf_proof.png`](file:///root/.gemini/antigravity-cli/brain/2f00e452-11f9-4327-a0f0-4900f5dcc21b/qubes_dom0_clean_ovmf_proof.png)
* **Exact Symptom**: Black screen immediately following GRUB multiboot execution.
* **Root Cause Analysis**: Qubes OS Xen kernel defaults to `console=none` and loads `plymouth` with `quiet`. When QEMU uses `qxl` or `virtio-gpu`, Xen fails to initialize modesetting without native KMS drivers, resulting in a dark display server.
* **Resolution**: Strip `quiet` from GRUB `module2` command line, pass `nomodeset`, and set video model to standard `vga` with 64MB VRAM.

---

## 2. Interactive GRUB Kernel Command Line Editing

### Original GRUB Parameters (Default Qubes ISO):
```text
multiboot2 /images/pxeboot/xen.gz console=none
module2 /images/pxeboot/vmlinuz inst.repo=hd:LABEL=QUBES-R4-3-1-X86-64 plymouth.ignore-serial-consoles rd.live.check quiet
module2 /images/pxeboot/initrd.img
```

### Hardened Verbose GRUB Parameters (`quiet` Removed):
```text
multiboot2 /images/pxeboot/xen.gz console=vga loglvl=all guest_loglvl=all
module2 /images/pxeboot/vmlinuz inst.repo=hd:LABEL=QUBES-R4-3-1-X86-64 plymouth.ignore-serial-consoles nomodeset vga=current
module2 /images/pxeboot/initrd.img
```

* **Screenshot Verification**:
  - GRUB Edit Screen: [`qubes_grub_edit_proof.png`](file:///root/.gemini/antigravity-cli/brain/2f00e452-11f9-4327-a0f0-4900f5dcc21b/qubes_grub_edit_proof.png)
  - `quiet` Parameter Removed: [`qubes_grub_quiet_removed_proof.png`](file:///root/.gemini/antigravity-cli/brain/2f00e452-11f9-4327-a0f0-4900f5dcc21b/qubes_grub_quiet_removed_proof.png)

---

## 3. Implementation-Ready QEMU Libvirt Domain XML Blueprint

```xml
<domain type='kvm'>
  <name>qubes-nested-powerhouse</name>
  <memory unit='KiB'>16777216</memory>
  <currentMemory unit='KiB'>16777216</currentMemory>
  <vcpu placement='static'>8</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <loader readonly='yes' type='pflash' format='qcow2'>/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2</loader>
    <nvram template='/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2' templateFormat='qcow2' format='qcow2'>/var/lib/libvirt/qemu/nvram/qubes-nested_VARS.qcow2</nvram>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <feature policy='require' name='vmx'/>
  </cpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='/var/lib/libvirt/images/qubes-dom0-agentic.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/var/lib/libvirt/images/Qubes-R4.3.1-x86_64.iso'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='vga' vram='65536' heads='1' primary='yes'/>
    </video>
  </devices>
</domain>
```

---

## 4. Deep Research Tasks & Prompts for AI Agents

When deploying autonomous AI research agents to optimize Qubes OS nested virtualization, provide the following prompt:

```text
PROMPT FOR DEEP RESEARCH SUBAGENT:
==================================
Investigate the precise requirements for booting Qubes OS R4.3.1 (Xen 4.19 hypervisor + Fedora 41 Dom0) inside a KVM/QEMU virtual machine under Fedora/SecureBlue Linux.

Your analysis must specifically solve:
1. Xen Hypervisor VGA/GOP Handoff: How to prevent the black screen freeze when Xen initializes the Dom0 kernel under QEMU VGA vs QXL vs Virtio-GPU devices.
2. EDK2 OVMF Memory Protections: How to configure OVMF NVRAM to allow non-NX clean multiboot2 loaders without triggering PageFaultExitBoot errors.
3. GRUB Automation: Define exact kernel parameters (e.g. console=vga nomodeset i915.alpha_support=1 xen-fbfront.video=...) to ensure Anaconda installer and Dom0 Xfce rendering display cleanly at 1920x1080 resolution.
```
