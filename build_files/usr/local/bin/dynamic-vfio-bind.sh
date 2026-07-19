#!/bin/bash
set -e

PROFILE_A_GPU="0000:01:00.0"
PROFILE_A_SND="0000:01:00.1"
PROFILE_B_GPU="0000:02:00.0"
PROFILE_B_SND="0000:02:00.1"

if grep -q "Intel Core Ultra 9 285H" /proc/cpuinfo; then
   TARGET_GPU=$PROFILE_A_GPU
   TARGET_SND=$PROFILE_A_SND
   IS_BLACKWELL=1
elif grep -q "AMD Ryzen 7 7800X3D" /proc/cpuinfo; then
   TARGET_GPU=$PROFILE_B_GPU
   TARGET_SND=$PROFILE_B_SND
   IS_BLACKWELL=0
else
   exit 0
fi

unbind_device() {
   if [ -e "/sys/bus/pci/devices/$1/driver/unbind" ]; then
       echo "$1" > "/sys/bus/pci/devices/$1/driver/unbind"
   fi
}

bind_vfio() {
   local vendor_device=$(cat /sys/bus/pci/devices/$1/vendor /sys/bus/pci/devices/$1/device | sed 's/0x//g' | tr '
' ' ')
   echo "$vendor_device" > /sys/bus/pci/drivers/vfio-pci/new_id
   echo "$1" > /sys/bus/pci/drivers/vfio-pci/bind || true
}

if [ "$IS_BLACKWELL" -eq 1 ]; then
   modprobe nvidia_open || modprobe nvidia
   sleep 5
   unbind_device $TARGET_GPU
   unbind_device $TARGET_SND
   modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia_open nvidia || true
fi

echo 14 > "/sys/bus/pci/devices/$TARGET_GPU/resource1_resize" 2>/dev/null || \
echo 13 > "/sys/bus/pci/devices/$TARGET_GPU/resource1_resize" 2>/dev/null || true

modprobe vfio-pci
bind_vfio $TARGET_GPU
bind_vfio $TARGET_SND
