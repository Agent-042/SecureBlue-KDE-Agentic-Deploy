# G16 BuildBlue Architectural Pulse & Deep Research Synthesis
1. **The Dummy Plug Mandate**: Software EDID spoofing is fragile. A physical $7 HDMI 2.1 dummy plug in the dGPU is the official SPDM-mandated solution to unblock the `sd-pam` hang.
2. **Zero-Layer Streaming Strategy**: Shifted from native Looking Glass to Flatpak-based Moonlight as the optimal host-streaming solution for immutable OS.
3. **IOMMU Deep Research Result**: The 42-bit Intel Arrow Lake-H IOMMU limit is a HARD silicon limit (4TB max). Fix: `<maxphysaddr mode="emulate" bits="42"/>` in libvirt XML to prevent -22 Invalid Argument mapping faults.
4. **Blackwell GSP Initialization**: RTX 5080 (GB203) cannot use early `vfio-pci` binding. It requires `nvidia-open` to load first for ~4 seconds to initialize GSP firmware via RPC, followed by a dynamic re-bind to `vfio-pci`.
5. **ReBAR Support**: Requires `pci=realloc` kernel arg and sysfs scaling down via `resource1_resize`.
