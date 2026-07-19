FROM ghcr.io/secureblue/kinoite-main-hardened:44 AS base
RUN dnf install -y libvirt qemu-kvm virt-manager virt-install edk2-ovmf xmlstarlet pciutils && dnf clean all
RUN mkdir -p /usr/lib/bootc/kargs.d
RUN echo 'kargs = ["intel_iommu=on", "amd_iommu=on", "pci=realloc", "rd.driver.pre=vfio_pci"]' > /usr/lib/bootc/kargs.d/99-vfio-unified.toml
RUN echo 'add_drivers+=" vfio vfio_iommu_type1 vfio_pci "' > /etc/dracut.conf.d/10-vfio.conf && \
    echo 'force_drivers+=" vfio vfio_iommu_type1 vfio_pci "' >> /etc/dracut.conf.d/10-vfio.conf
RUN echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nvidia.conf && \
    echo "blacklist nvidia" >> /etc/modprobe.d/blacklist-nvidia.conf
COPY build_files/usr/local/bin/dynamic-vfio-bind.sh /usr/local/bin/dynamic-vfio-bind.sh
COPY build_files/etc/systemd/system/dynamic-vfio.service /etc/systemd/system/dynamic-vfio.service
RUN chmod +x /usr/local/bin/dynamic-vfio-bind.sh
RUN systemctl enable dynamic-vfio.service
COPY build_files/usr/share/ublue-os/just/60-custom-vfio.just /usr/share/ublue-os/just/60-custom-vfio.just
RUN dracut -f -v --regenerate-all
