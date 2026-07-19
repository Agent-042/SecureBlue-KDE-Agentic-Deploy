# G16 BuildBlue Architectural Pulse
1. **The Dummy Plug Mandate**: Software EDID spoofing is fragile. A physical $7 HDMI 2.1 dummy plug in the dGPU is the official SPDM-mandated solution to unblock the `sd-pam` hang.
2. **Zero-Layer Streaming Strategy**: Shifted from native Looking Glass to Flatpak-based Moonlight as the optimal host-streaming solution for immutable OS.
3. **39-Bit IOMMU Workaround**: `host-phys-bits-limit=39` QEMU workaround bypasses the 42-bit Intel Arrow Lake-H IOMMU limit.
