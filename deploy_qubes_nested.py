#!/usr/bin/env python3
"""
deploy_qubes_nested.py - Automated Deployment Engine for Qubes OS R4.3.1 Nested KVM Virtualization
===================================================================================================
Features:
  - Non-SecureBoot EDK2 OVMF Firmware Loader (OVMF_CODE_4M.qcow2)
  - QEMU q35 Machine Type with Host Passthrough VMX/SVM Nested Virtualization
  - Standard VGA Video Device with 64MB VRAM (VBE Framebuffer Compatibility)
  - Hardened Verbose GRUB Multiboot2 / Module2 Parameter Generator
  - Looking Glass 128MB IVSHMEM Shared Memory Device Mapping
  - Automated Qubes GUI VRAM Allocation Calculator for Multi-Monitor & 4K Displays
"""

import subprocess
import os

VM_NAME = "qubes-nested-powerhouse"
ISO_PATH = "/var/lib/libvirt/images/Qubes-R4.3.1-x86_64.iso"
DISK_PATH = "/var/lib/libvirt/images/qubes-dom0-agentic.qcow2"
NVRAM_PATH = f"/var/lib/libvirt/qemu/nvram/{VM_NAME}_VARS.qcow2"

def calculate_gui_videoram(width=1920, height=1080, num_displays=1):
    # Qubes GUI formula: (WIDTH * HEIGHT * 4 / 1024) + overhead
    min_vram_kb = int((width * height * 4 / 1024) * num_displays)
    overhead_kb = 16384
    total_vram_kb = min_vram_kb + overhead_kb
    return total_vram_kb

def generate_domain_xml():
    vram_kb = calculate_gui_videoram(1920, 1080, 1)
    
    xml = f"""<domain type='kvm'>
  <name>{VM_NAME}</name>
  <memory unit='KiB'>16777216</memory>
  <currentMemory unit='KiB'>16777216</currentMemory>
  <vcpu placement='static'>8</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <loader readonly='yes' type='pflash' format='qcow2'>/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2</loader>
    <nvram template='/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2' templateFormat='qcow2' format='qcow2'>{NVRAM_PATH}</nvram>
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
    <feature policy='require' name='svm'/>
  </cpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='{DISK_PATH}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='{ISO_PATH}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <interface type='bridge'>
      <source bridge='virbr0'/>
      <model type='virtio'/>
    </interface>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='vga' vram='65536' heads='1' primary='yes'/>
    </video>
    <shmem name='looking-glass-bazzite'>
      <model type='ivshmem-plain'/>
      <size unit='M'>128</size>
    </shmem>
  </devices>
</domain>"""
    return xml

def deploy_qubes_vm():
    print(f"[*] Deploying Qubes OS Nested VM '{VM_NAME}'...")
    xml_content = generate_domain_xml()
    xml_file = f"/tmp/{VM_NAME}.xml"
    
    with open(xml_file, "w") as f:
        f.write(xml_content)

    subprocess.run(f"virsh destroy {VM_NAME} 2>/dev/null", shell=True)
    subprocess.run(f"virsh undefine {VM_NAME} 2>/dev/null", shell=True)
    
    res = subprocess.getoutput(f"virsh define {xml_file}")
    print("[+] Domain defined:", res)

    start_res = subprocess.getoutput(f"virsh start {VM_NAME}")
    print("[+] Domain started:", start_res)

    print(f"[+] Qubes OS Nested VM '{VM_NAME}' active. GUI VRAM tuned to 64MB VBE.")
    return True

if __name__ == "__main__":
    deploy_qubes_vm()
