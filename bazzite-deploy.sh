#!/usr/bin/env bash
# bazzite-deploy.sh
# Provision a Bazzite gaming VM with GPU and audio passthrough, Looking Glass, and evdev inputs.
# SPDM Manifest: Self-Parsing Deployment Manifest format.
#
# HARDWARE TARGET: ASUS ROG Zephyrus G16 OLED
# PCI IDs from G16 reconnaissance (see .assets/docs/inventory/g16-bazzite-passthrough-inventory.md):
#   GPU:  0000:01:00.0  NVIDIA RTX 5080 Mobile  [10de:2c59]
#   Audio: 0000:01:00.1  NVIDIA HD Audio        [10de:22e9]
#   IOMMU Group 18: PERFECT ISOLATION

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Install virtualization stack, kvmfr kernel module, and client tools
rpm-ostree install -y libvirt qemu-kvm virt-install edk2-ovmf looking-glass-client

# Enable kvmfr kernel module for Looking Glass shared memory
modprobe kvmfr static_size_mb=128

# Enable the libvirtd system service
systemctl enable libvirtd.service

# Add kvmfr to dracut so it persists across reboots
mkdir -p /etc/dracut.conf.d
echo 'add_drivers+=" kvmfr "' > /etc/dracut.conf.d/99-kvmfr.conf

# Configure firewalld isolated zone for VM networking
firewall-cmd --permanent --new-zone=isolated-vm 2>/dev/null || true
firewall-cmd --permanent --zone=isolated-vm --set-target=DROP
firewall-cmd --permanent --zone=isolated-vm --add-rich-rule='rule family="ipv4" source NOT address="192.168.100.0/24" accept'
firewall-cmd --reload

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
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/ || cmd ~ /^modprobe/) {
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
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/ || cmd ~ /^modprobe/) {
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
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/ || cmd ~ /^modprobe/) {
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

readonly VM_NAME="bazzite-vm"
readonly VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
readonly VM_XML_PATH="/var/lib/libvirt/qemu/${VM_NAME}.xml"
readonly ISO_PATH="/var/lib/libvirt/images/bazzite.iso"

# --- REAL PCI IDs FROM G16 RECONNAISSANCE ---
# See: .assets/docs/inventory/g16-bazzite-passthrough-inventory.md
readonly GPU_BUS="01"
readonly GPU_SLOT="00"
readonly GPU_FUNC="0"
readonly AUDIO_FUNC="1"

echo "=== BAZZITE VM DEPLOYMENT ==="
echo "Target: ${VM_NAME}"
echo "GPU:    0000:${GPU_BUS}:${GPU_SLOT}.${GPU_FUNC} (RTX 5080 Mobile)"
echo "Audio:  0000:${GPU_BUS}:${GPU_SLOT}.${AUDIO_FUNC} (NVIDIA HD Audio)"
echo ""

# 1. Verify vfio-pci binding
echo "[1/6] Verifying GPU is bound to vfio-pci..."
if ! lspci -nnk -s "${GPU_BUS}:${GPU_SLOT}.${GPU_FUNC}" | grep -q "vfio-pci"; then
    echo "ERROR: GPU is not bound to vfio-pci. Run:"
    echo "  run0 rpm-ostree kargs --append='intel_iommu=on' --append='iommu=pt'"
    echo "  run0 rpm-ostree kargs --append='rd.driver.pre=vfio-pci'"
    echo "  run0 rpm-ostree kargs --append='vfio-pci.ids=10de:2c59,10de:22e9'"
    exit 1
fi
echo "OK: GPU bound to vfio-pci"

# 2. Create isolated libvirt network
echo "[2/6] Creating isolated network..."
cat > /tmp/isolated-vm-net.xml <<'NETEOF'
<network>
  <name>isolated-vm-net</name>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.10' end='192.168.100.50'/>
    </dhcp>
  </ip>
</network>
NETEOF
virsh net-define /tmp/isolated-vm-net.xml 2>/dev/null || true
virsh net-autostart isolated-vm-net 2>/dev/null || true
virsh net-start isolated-vm-net 2>/dev/null || true
echo "OK: Network configured"

# 3. Configure kvmfr for Looking Glass
echo "[3/6] Configuring kvmfr (Looking Glass shared memory)..."
if [[ ! -e /dev/kvmfr0 ]]; then
    modprobe kvmfr static_size_mb=128 2>/dev/null || true
fi
if [[ -e /dev/kvmfr0 ]]; then
    chmod 660 /dev/kvmfr0
    chown root:kvm /dev/kvmfr0 2>/dev/null || true
    echo "OK: /dev/kvmfr0 ready"
else
    echo "WARNING: /dev/kvmfr0 not available. Looking Glass will use ivshmem fallback."
fi

# 4. Create virtual disk
echo "[4/6] Creating virtual disk..."
if [[ ! -f "${VM_DISK_PATH}" ]]; then
    qemu-img create -f qcow2 "${VM_DISK_PATH}" 100G
    echo "OK: Created 100G sparse disk"
else
    echo "OK: Disk already exists at ${VM_DISK_PATH}"
fi

# 5. Check for Bazzite ISO
echo "[5/6] Checking for Bazzite ISO..."
if [[ ! -f "${ISO_PATH}" ]]; then
    echo "WARNING: No Bazzite ISO found at ${ISO_PATH}"
    echo "Download the latest Bazzite ISO from:"
    echo "  https://bazzite.gg/#download"
    echo "Then place it at: ${ISO_PATH}"
    echo ""
    echo "To install now, run:"
    echo "  run0 virt-install \\"
    echo "    --name ${VM_NAME} \\"
    echo "    --memory 16384 --vcpus 8 \\"
    echo "    --cpu host-passthrough \\"
    echo "    --machine q35 \\"
    echo "    --disk path=${VM_DISK_PATH},bus=virtio \\"
    echo "    --cdrom ${ISO_PATH} \\"
    echo "    --network network=isolated-vm-net \\"
    echo "    --graphics none \\"
    echo "    --boot uefi"
    echo ""
    echo "After installation, re-run this script to define the VM with GPU passthrough."
    exit 0
fi
echo "OK: ISO found at ${ISO_PATH}"

# 6. Generate and define VM XML with GPU passthrough
echo "[6/6] Generating VM XML with GPU passthrough..."
cat > /tmp/bazzite-vm.xml <<XMLEOF
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>${VM_NAME}</name>
  <memory unit='KiB'>16777216</memory>
  <currentMemory unit='KiB'>16777216</currentMemory>
  <vcpu placement='static'>8</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd</nvram>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vendor_id state='on' value='NVKVMFIX'/>
    </hyperv>
    <kvm>
      <hidden state='on'/>
    </kvm>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
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
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${ISO_PATH}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'/>
    <controller type='pci' index='0' model='pcie-root'/>
    <interface type='network'>
      <source network='isolated-vm-net'/>
      <model type='virtio'/>
    </interface>

    <!-- Looking Glass kvmfr shared memory -->
    <shmem name='looking-glass'>
      <model type='ivshmem-plain'/>
      <size unit='M'>128</size>
    </shmem>

    <!-- RTX 5080 GPU Passthrough -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x${GPU_BUS}' slot='0x${GPU_SLOT}' function='0x${GPU_FUNC}'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x09' slot='0x00' function='0x0'/>
    </hostdev>

    <!-- NVIDIA HD Audio Passthrough -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x${GPU_BUS}' slot='0x${GPU_SLOT}' function='0x${AUDIO_FUNC}'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x09' slot='0x00' function='0x1'/>
    </hostdev>

    <!-- No virtual VGA - dGPU is primary -->
    <video>
      <model type='none'/>
    </video>
    <graphics type='spice' autoport='yes'>
      <listen type='none'/>
    </graphics>

    <input type='tablet' bus='usb'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
    </rng>
    <memballoon model='none'/>
  </devices>

  <!-- Evdev input passthrough toggle (L-Ctrl + R-Ctrl) -->
  <qemu:commandline>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=mouse1,evdev=/dev/input/by-id/PLACEHOLDER_MOUSE_ID'/>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=kbd1,evdev=/dev/input/by-id/PLACEHOLDER_KEYBOARD_ID,grab_all=on,repeat=on'/>
  </qemu:commandline>
</domain>
XMLEOF

mkdir -p "$(dirname "${VM_XML_PATH}")"
cp /tmp/bazzite-vm.xml "${VM_XML_PATH}"

if virsh define "${VM_XML_PATH}"; then
    echo ""
    echo "=== SUCCESS ==="
    echo "VM '${VM_NAME}' defined with GPU passthrough."
    echo ""
    echo "Next steps:"
    echo "  1. Fill in evdev device IDs in ${VM_XML_PATH}:"
    echo "     ls /dev/input/by-id/"
    echo "  2. Start the VM: virsh start ${VM_NAME}"
    echo "  3. Connect via Looking Glass: looking-glass-client"
    echo ""
    echo "Toggle input with L-Ctrl + R-Ctrl"
else
    echo "ERROR: virsh define failed. Check XML syntax." >&2
    exit 1
fi
