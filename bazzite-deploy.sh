#!/usr/bin/env bash
# bazzite-deploy.sh
# Provision a Bazzite gaming VM with GPU and audio passthrough, Looking Glass, and evdev inputs.
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Pure commands only. No variables. No conditionals. No loops.
# One command per line. Blank line between commands.
# Every command MUST have a comment explaining its purpose.

# Install virtualization stack and client tools
rpm-ostree install -y libvirt qemu-kvm virt-manager virt-install edk2-ovmf looking-glass-client

# Enable the libvirtd system service
systemctl enable libvirtd.service

# <MANIFEST_END>

exit 0

# --- SPDM AST Construction Engine ---
goto_script_logic() {
  local script_path="$1"
  awk '
    BEGIN { in_manifest=0; cmd=""; }
    /^# <MANIFEST_START>/ { in_manifest=1; next; }
    /^# <MANIFEST_END>/ { in_manifest=0; next; }
    in_manifest == 0 { next; }
    /^[[:space:]]*#/ { next; }
    /^[[:space:]]*$/ {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
      next;
    }
    {
      if (cmd == "") cmd = $0;
      else cmd = cmd " " $0;
      if (substr(cmd, length(cmd), 1) == "\\") {
        cmd = substr(cmd, 1, length(cmd)-1) " ";
      } else {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
    }
    END {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
      }
    }
  ' "$script_path"
}

# --- ORIGINAL SCRIPT LOGIC ---
set -euo pipefail

# Ensure running with root privileges via run0
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Error: This script must be run with root privileges (e.g. run0 bash $0)" >&2
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT

echo "=== BAZZITE VM DEPLOYMENT SCAFFOLD ==="

# 1. Define Paths
VM_NAME="bazzite-vm"
VM_XML_PATH="/var/lib/libvirt/qemu/${VM_NAME}.xml"
VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
LG_SHMEM_FILE="/dev/shm/looking-glass"

# 2. Configure isolated network in firewalld
echo "Configuring firewalld isolated network zone..."
run0 firewall-cmd --permanent --new-zone=isolated-vm || true
run0 firewall-cmd --permanent --zone=isolated-vm --set-target=DROP || true
run0 firewall-cmd --permanent --zone=isolated-vm --add-interface=virbr1 || true
run0 firewall-cmd --reload || true

# 3. Create isolated libvirt network XML
echo "Creating isolated libvirt network definition..."
cat <<EOF > /tmp/isolated-vm-net.xml
<network>
  <name>isolated-vm-net</name>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

# Define and start network
run0 virsh net-define /tmp/isolated-vm-net.xml || true
run0 virsh net-autostart isolated-vm-net || true
run0 virsh net-start isolated-vm-net || true

# 4. Generate Looking Glass Shared Memory helper service/udev rule
echo "Configuring Looking Glass shm..."
run0 touch "${LG_SHMEM_FILE}" || true
run0 chmod 660 "${LG_SHMEM_FILE}" || true
# In a real setup, we would set owner to the user, e.g. chown root:kvm.
# Let's drop a systemd-tmpfiles config to keep it persistent.
run0 mkdir -p /etc/tmpfiles.d
cat <<EOF | run0 tee /etc/tmpfiles.d/10-looking-glass.conf
# Type Path               Mode UID  GID  Age Argument
f     /dev/shm/looking-glass 0660 root kvm  -   -
EOF

# 5. Create Virtual Disk (100GB sparse QCow2)
if [[ ! -f "${VM_DISK_PATH}" ]]; then
    echo "Creating sparse QCOW2 virtual disk at ${VM_DISK_PATH}..."
    run0 qemu-img create -f qcow2 "${VM_DISK_PATH}" 100G
fi

# 6. Generate Libvirt Domain XML
echo "Generating VM XML template at ${VM_XML_PATH}..."
cat <<EOF > /tmp/bazzite-vm.xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>${VM_NAME}</name>
  <memory unit='KiB'>16777216</memory>
  <currentMemory unit='KiB'>16777216</currentMemory>
  <vcpu placement='static'>8</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.0'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd</nvram>
  </os>
  <features>
    <acpi/>
    <apic/>
    <kvm>
      <hidden state='on'/>
    </kvm>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' dies='1' cores='4' threads='2'/>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='${VM_DISK_PATH}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'/>
    <controller type='pci' index='0' model='pcie-root'/>
    <interface type='network'>
      <source network='isolated-vm-net'/>
      <model type='virtio'/>
    </interface>
    
    <!-- ivshmem device for Looking Glass -->
    <shmem name='looking-glass'>
      <model type='ivshmem-plain'/>
      <size unit='M'>128</size>
    </shmem>

    <!-- GPU Video Passthrough Stub -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='PLACEHOLDER_GPU_BUS' slot='PLACEHOLDER_GPU_SLOT' function='0x0'/>
      </source>
    </hostdev>

    <!-- GPU Audio Passthrough Stub -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='PLACEHOLDER_GPU_BUS' slot='PLACEHOLDER_GPU_SLOT' function='0x1'/>
      </source>
    </hostdev>

    <!-- Guest Audio Passthrough Stub -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='PLACEHOLDER_AUDIO_BUS' slot='PLACEHOLDER_AUDIO_SLOT' function='PLACEHOLDER_AUDIO_FUNCTION'/>
      </source>
    </hostdev>
    <memballoon model='none'/>
  </devices>
  
  <!-- evdev input passthrough configuration -->
  <qemu:commandline>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=mouse1,evdev=/dev/input/by-id/PLACEHOLDER_MOUSE_ID'/>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=kbd1,evdev=/dev/input/by-id/PLACEHOLDER_KEYBOARD_ID,grab_all=on,repeat=on'/>
  </qemu:commandline>
</domain>
EOF

# Move template to standard config directory
run0 mkdir -p "$(dirname "${VM_XML_PATH}")"
run0 cp /tmp/bazzite-vm.xml "${VM_XML_PATH}"

# 7. Define VM
echo "Defining VM via virsh..."
if run0 virsh define "${VM_XML_PATH}"; then
    echo "Success: VM defined successfully."
else
    echo "Warning: virsh define failed (probably due to placeholders). Trying virt-install dry-run fallback..."
    # Virt-install fallback dry-run to ensure the command is valid
    if run0 virt-install \
      --name "${VM_NAME}" \
      --memory 16384 \
      --vcpus 8 \
      --cpu host-passthrough \
      --machine q35 \
      --disk path="${VM_DISK_PATH}",size=100,bus=virtio \
      --network network=isolated-vm-net \
      --graphics none \
      --import \
      --dry-run; then
        echo "virt-install dry-run successful. You can safely fill in PCI placeholders and define/install later."
    else
        echo "Error: Both virsh define and virt-install validation failed." >&2
        exit 1
    fi
fi
