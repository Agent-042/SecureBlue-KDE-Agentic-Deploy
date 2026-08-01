#!/usr/bin/env bash
<<<<<<< HEAD
# vfio-bind-secondary-gpu.sh
# Bind the non-primary NVIDIA GPU to vfio-pci for PCI passthrough.
# Intended for dual-NVIDIA workstations (e.g. AMD Ryzen 9 9950X + dual RTX 4080).
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Runtime/user-facing tool — no build-phase commands required.
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
=======
# Bind the non-primary NVIDIA GPU to vfio-pci for PCI passthrough.
# Intended for dual-NVIDIA workstations (e.g. AMD Ryzen 9 9950X + dual RTX 4080)
# or single NVIDIA GPU with integrated AMD/Intel graphics.

>>>>>>> 28adf4f ([Agy-AutoSync] Automated infrastructure state backup (2026-08-01T04:57:44Z))
set -uo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: this script must be run as root" >&2
    exit 1
fi

if ! lsmod | grep -qE '^vfio_pci|^vfio-pci'; then
    echo "Loading vfio-pci module..."
    if ! modprobe vfio-pci; then
        echo "Error: vfio-pci module is not loaded and could not be loaded" >&2
        exit 1
    fi
    sleep 1
fi

<<<<<<< HEAD
=======
# Gather NVIDIA GPU controllers (VGA or 3D controller) grouped by PCI slot.
>>>>>>> 28adf4f ([Agy-AutoSync] Automated infrastructure state backup (2026-08-01T04:57:44Z))
declare -a gpu_slots=()
while IFS= read -r line; do
    bdf="${line%% *}"
    slot="${bdf%.*}"
    gpu_slots+=("$slot")
done < <(lspci -nn -d 10de: | awk '/VGA compatible controller|3D controller/{print $1}')

count="${#gpu_slots[@]}"
echo "Found $count NVIDIA GPU controller(s)"

<<<<<<< HEAD
if [[ "$count" -lt 2 ]]; then
    echo "Error: at least 2 NVIDIA GPUs are required to safely bind the secondary; found $count" >&2
    exit 1
fi

=======
if [[ "$count" -lt 1 ]]; then
    echo "Error: no NVIDIA GPUs found" >&2
    exit 1
fi

if [[ "$count" -lt 2 ]]; then
    # If there is another non-NVIDIA VGA/3D controller (like AMD integrated), we can safely bind our single NVIDIA GPU.
    if lspci -nn | grep -E "VGA compatible controller|3D controller" | grep -qv "NVIDIA"; then
        echo "Found non-NVIDIA VGA/3D controller. Safe to bind the single NVIDIA GPU."
    else
        echo "Error: at least 2 NVIDIA GPUs (or 1 NVIDIA and 1 non-NVIDIA display GPU) are required to safely bind; found $count" >&2
        exit 1
    fi
fi

# Detect the primary GPU by looking for a connected DRM output.
>>>>>>> 28adf4f ([Agy-AutoSync] Automated infrastructure state backup (2026-08-01T04:57:44Z))
primary_slot=""
for slot in "${gpu_slots[@]}"; do
    for dev in /sys/bus/pci/devices/0000:"$slot".*; do
        if [[ -d "$dev/drm" ]]; then
            for status in "$dev"/drm/card*/status; do
                if [[ -f "$status" ]] && [[ "$(cat "$status" 2>/dev/null)" == "connected" ]]; then
                    primary_slot="$slot"
                    break 3
                fi
            done
        fi
    done
done

if [[ -z "$primary_slot" ]]; then
<<<<<<< HEAD
    primary_slot="${gpu_slots[0]}"
    echo "Warning: could not detect connected display; assuming primary GPU slot is $primary_slot" >&2
fi

echo "Primary GPU slot: $primary_slot"

for slot in "${gpu_slots[@]}"; do
    if [[ "$slot" == "$primary_slot" ]]; then
=======
    # If we have another VGA/3D controller (like AMD integrated graphics), we assume that other controller is the primary,
    # and all NVIDIA cards are secondary.
    if lspci -nn | grep -E "VGA compatible controller|3D controller" | grep -qv "NVIDIA"; then
        echo "Non-NVIDIA display controller detected; assuming all NVIDIA GPUs are secondary." >&2
    else
        primary_slot="${gpu_slots[0]}"
        echo "Warning: could not detect connected display; assuming primary GPU slot is $primary_slot" >&2
    fi
fi

if [[ -n "$primary_slot" ]]; then
    echo "Primary GPU slot: $primary_slot"
fi

# Bind every function on each non-primary NVIDIA GPU slot to vfio-pci.
for slot in "${gpu_slots[@]}"; do
    if [[ -n "$primary_slot" ]] && [[ "$slot" == "$primary_slot" ]]; then
>>>>>>> 28adf4f ([Agy-AutoSync] Automated infrastructure state backup (2026-08-01T04:57:44Z))
        continue
    fi

    echo "Binding secondary GPU slot $slot to vfio-pci"

    while IFS= read -r line; do
        bdf="${line%% *}"
        devpath="/sys/bus/pci/devices/0000:$bdf"

        if [[ -L "$devpath/driver" ]]; then
            driver="$(basename "$(readlink -f "$devpath/driver")")"
            if [[ "$driver" == "vfio-pci" ]]; then
                echo "  $bdf already bound to vfio-pci"
                continue
            fi
            echo "  $bdf unbinding from $driver"
            if ! echo "$bdf" > "/sys/bus/pci/drivers/$driver/unbind" 2>/dev/null; then
                echo "  Error: failed to unbind $bdf from $driver" >&2
                continue
            fi
        fi

        vendor_device="$(lspci -n -s "$bdf" | awk '{print $3}')"
        if [[ -n "$vendor_device" ]]; then
            vid="${vendor_device%:*}"
            did="${vendor_device#*:}"
            echo "  $bdf registering $vid $did with vfio-pci"
<<<<<<< HEAD
            echo "$vid $did" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
        fi

=======
            # new_id returns EEXIST if the ID is already registered; that is fine.
            echo "$vid $did" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
        fi

        # Write driver_override to ensure vfio-pci claims it
        echo "vfio-pci" > "$devpath/driver_override" 2>/dev/null || true

        # The driver may auto-bind after new_id; ignore errors here and verify below.
>>>>>>> 28adf4f ([Agy-AutoSync] Automated infrastructure state backup (2026-08-01T04:57:44Z))
        echo "0000:$bdf" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true

        if [[ -L "$devpath/driver" ]] && [[ "$(basename "$(readlink -f "$devpath/driver")")" == "vfio-pci" ]]; then
            echo "  $bdf bound to vfio-pci"
        else
            echo "  Warning: $bdf may not be bound to vfio-pci" >&2
        fi
    done < <(lspci -nn -d 10de: | awk -v slot="$slot" '$1 ~ "^"slot"\\." {print $1}')
done

echo "VFIO secondary GPU bind complete"
