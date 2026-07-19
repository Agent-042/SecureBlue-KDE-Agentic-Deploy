@setup-gaming-vm:
   echo "Configuring Bazzite Gaming VM..."
   ujust set-libvirt-daemons on
   sudo systemctl enable --now libvirtd
   sudo virsh net-autostart default
   sudo virsh net-start default || true
   if grep -q "Intel Core Ultra 9 285H" /proc/cpuinfo; then
       xmlstarlet ed -L -s "/domain/cpu" -t elem -n "maxphysaddr" -v "" \
                    -i "/domain/cpu/maxphysaddr" -t attr -n "mode" -v "emulate" \
                    -i "/domain/cpu/maxphysaddr" -t attr -n "bits" -v "42" \
                    /etc/libvirt/qemu/bazzite-gaming.xml
   fi
