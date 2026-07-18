Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 rpm-ostree kargs --append=amd_iommu=on --append=iommu=pt --append=kvm.ignore_msrs=1 --append=kvm_amd.npt=1 --append=kvm_amd.avic=1

run0 rpm-ostree install -y libvirt qemu-kvm virt-manager virt-install edk2-ovmf

run0 systemctl enable --now libvirtd virtlogd

run0 modprobe vfio vfio_iommu_type1 vfio_pci

## Script Logic ##
# File: modules/vfio-sandbox/module.yml
type: files
files:
  - source: vfio-sandbox/usr
    destination: /usr

# File: config/files/usr/etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci

# File: modules/vfio-workstation/module.yml (optional secondary GPU binding)
type: files
files:
  - source: vfio-workstation/usr
    destination: /usr

# File: config/files/usr/bin/vfio-bind-secondary-gpu.sh
#!/bin/bash
# Binds secondary GPU to vfio-pci for PCI passthrough
GPU_PCI_ID="$(lspci -nn | grep -E 'VGA|3D controller' | awk 'NR==2{print $1}')"
GPU_VENDORS="$(lspci -nn | grep -E 'VGA|3D controller' | awk 'NR==2{print $NF}')"
echo "vfio-pci" > /sys/bus/pci/devices/0000:${GPU_PCI_ID}/driver_override
modprobe vfio-pci ids=${GPU_VENDORS}

# File: config/files/usr/lib/systemd/system/vfio-bind-secondary-gpu.service
[Unit]
Description=Bind secondary GPU to VFIO
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/bin/vfio-bind-secondary-gpu.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
