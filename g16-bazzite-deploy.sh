#!/bin/bash
echo "Injecting Arrow Lake 42-bit IOMMU XML patch..."
xmlstarlet ed -L -s "/domain/cpu" -t elem -n "maxphysaddr" -v "" \
    -i "/domain/cpu/maxphysaddr" -t attr -n "mode" -v "emulate" \
    -i "/domain/cpu/maxphysaddr" -t attr -n "bits" -v "42" \
    /etc/libvirt/qemu/bazzite-gaming.xml

echo "Installing Moonlight for Zero-Layer Streaming..."
flatpak install flathub com.moonlight_stream.Moonlight -y
