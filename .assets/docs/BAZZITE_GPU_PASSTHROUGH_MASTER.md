# Bazzite Gaming VM & GPU Passthrough Master Integration Guide
### Zero-Latency Headless Streaming Pipeline for SecureBlue KDE
---

> [!NOTE]
> This guide is aligned with the [SPDM_CONSTITUTION.md](file:///root/SecureBlue-KDE-Agentic-Deploy/.assets/docs/SPDM_CONSTITUTION.md) and [CONTRIBUTING_Coding_Agent.md](file:///root/SecureBlue-KDE-Agentic-Deploy/.assets/docs/CONTRIBUTING_Coding_Agent.md) and acts as the living, breathing master operational blueprint for the project.

---

## Hardware Specifications

### Host A: G16 Laptop (Client)
* **CPU:** Intel(R) Core(TM) Ultra 9 285H (Arrow Lake, 16 Cores)
* **Integrated GPU (iGPU):** Intel Corporation Arrow Lake-P [Arc Pro 130T/140T] (Drives local laptop panel)
* **Dedicated GPU (dGPU):** NVIDIA Corporation GB203M / GN22-X9 [GeForce RTX 5080 Laptop GPU]
* **Memory:** 32 GiB RAM
* **OS:** SecureBlue KDE (Fedora-based atomic, hardened glibc and flatpak sandboxing)

### Host B: AMD Workstation (Server / Host VM)
* **CPU:** AMD Ryzen 7 7800X3D 8-Core Processor (3D V-Cache)
* **Integrated GPU (iGPU):** Advanced Micro Devices, Inc. [AMD/ATI] Raphael RDNA 2 (Drives motherboard display output to LG C1 48" monitor)
* **Dedicated GPU (dGPU):** NVIDIA Corporation AD103 [GeForce RTX 4080] (Passed entirely to Bazzite guest VM via VFIO)
* **Memory:** 32 GiB RAM
* **OS:** SecureBlue KDE (Fedora-based atomic)

---

## ## Human Logic ##

This section outlines the logical steps to perform, verify, and pair the headless Bazzite GPU Passthrough VM streaming architecture.

### Step 1: Headless Virtual Display Activation (No Dummy Plugs)
To allow the NVIDIA proprietary driver inside the headless Bazzite guest to initialize its framebuffers and Wayland compositor without a physical monitor or HDMI dummy plug attached:
1. SSH into the Bazzite guest VM.
2. Edit `/boot/loader/entries/ostree-1.conf` (and any other systemd-boot configuration entries).
3. Append `video=DP-1:3840x2160@120e` to the `options` line. The trailing `e` character forces the DP-1 port into a connected state.
4. Reboot the guest. The GPU will now boot natively at 4K resolution at 120Hz.

### Step 2: Sunshine Persistent User Session Configuration (Linger)
Because Sunshine stream server runs as a systemd user-level daemon, it normally exits when no user is graphically logged in:
1. Enable lingering for the `bazzite` user context so the systemd user manager remains alive headlessly post-boot:
   ```bash
   loginctl enable-linger bazzite
   ```
2. Enable the Sunshine user service under systemd `default.target` so it initializes on boot without a desktop session:
   ```bash
   mkdir -p /home/bazzite/.config/systemd/user/default.target.wants
   ln -sf /usr/lib/systemd/user/sunshine.service /home/bazzite/.config/systemd/user/default.target.wants/sunshine.service
   ```

### Step 3: Flatpak Overrides & Hardened Malloc Bypasses
SecureBlue preloads `hardened_malloc` inside all Flatpaks globally to enforce security. However, this blocks hardware-accelerated video decoding (VAAPI/NVDEC) inside Moonlight, resulting in black screens or massive stream lag.
1. Apply a system-wide or user-wide Flatpak override for the Moonlight client (`com.moonlight_stream.Moonlight`) to clear `LD_PRELOAD`:
   ```bash
   flatpak override --system --env=LD_PRELOAD="" com.moonlight_stream.Moonlight
   ```

### Step 4: Moonlight Configuration Pre-Staging
Moonlight's auto-discovery relies on local subnet UDP broadcasts (mDNS/Avahi), which cannot traverse virtual libvirt bridges or Tailscale tunnels. To bypass manual IP entries in Moonlight's interface:
1. Add Host B's Tailscale IP directly to G16 Laptop's Moonlight configuration file `/home/agent-042/.var/app/com.moonlight_stream.Moonlight/config/Moonlight Game Streaming Project/Moonlight.conf` under a `[hosts]` section:
   ```ini
   [hosts]
   1\address=100.82.139.39
   size=1
   ```
2. The computer `node-42` / `100.82.139.39` will immediately appear in the Moonlight interface without manual searching.

### Step 5: User-Space Port Forwarding over Tailscale
Because firewalld restricts forwarding and DNAT between different internal zones (e.g., the Tailscale zone to the libvirt bridge zone), utilize a user-space proxy using `socat` to relay TCP and UDP packets with sub-millisecond overhead:
1. Listen on Host B's interfaces (`0.0.0.0`) on all Sunshine streaming ports, and forward them directly to the Bazzite guest's bridge IP (`192.168.123.42`).
2. Open the streaming ports inside Host B's `FedoraWorkstation` firewalld zone:
   * **TCP:** `47989` (HTTPS Admin), `47990` (HTTP), `48010` (RTSP)
   * **UDP:** `47984` (Discovery), `47998` (Video), `47999` (Audio), `48000` (Control)

---

## ## Script Logic ##

This section contains the exact configuration files, systemd services, and automated scripts implementing the pipeline.

### 1. Host B User-Space Port Forwarding Service
Create this service on Host B under `/etc/systemd/system/bazzite-port-forward.service` to forward all stream traffic from G16/Tailscale to the Bazzite guest:

```ini
[Unit]
Description=Bazzite Stream Port Forwarding Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '\
  /usr/sbin/socat TCP4-LISTEN:47989,fork,reuseaddr TCP4:192.168.123.42:47989 & \
  /usr/sbin/socat TCP4-LISTEN:47990,fork,reuseaddr TCP4:192.168.123.42:47990 & \
  /usr/sbin/socat TCP4-LISTEN:48010,fork,reuseaddr TCP4:192.168.123.42:48010 & \
  /usr/sbin/socat UDP4-LISTEN:47984,fork,reuseaddr UDP4:192.168.123.42:47984 & \
  /usr/sbin/socat UDP4-LISTEN:47998,fork,reuseaddr UDP4:192.168.123.42:47998 & \
  /usr/sbin/socat UDP4-LISTEN:47999,fork,reuseaddr UDP4:192.168.123.42:47999 & \
  /usr/sbin/socat UDP4-LISTEN:48000,fork,reuseaddr UDP4:192.168.123.42:48000 & \
  wait'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Apply and start the service:
```bash
systemctl daemon-reload
systemctl enable --now bazzite-port-forward.service
```

### 2. Local One-Click Launcher (AMD Workstation Host B)
Saves to `/usr/local/bin/launch-bazzite-gaming.sh` on Host B. It detects if run under `root` (via run0/sudo) and gracefully downgrades context when starting the Moonlight Flatpak to prevent display-server authorization rejection:

```bash
#!/bin/bash
VM_NAME="bazzite-gaming"
VM_IP="192.168.123.42"
PORT=47989

# Verify VM State and start if not running
VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null)
if [ "$VM_STATE" != "running" ]; then
    virsh start "$VM_NAME"
fi

# Poll for network lease using Port 22 connectivity checks (ICMP ping is unreliable)
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/22" >/dev/null 2>&1; do sleep 1; done
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/${PORT}" >/dev/null 2>&1; do sleep 1; done

# Resolve active desktop user when executed as root (run0/sudo) to mount X11/Wayland context
REAL_USER="agent-042"
REAL_UID=1000
if [ "$EUID" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        REAL_USER="$SUDO_USER"
    else
        ACTIVE_SESSION_USER=$(loginctl list-sessions | grep -i active | awk '{print $3}' | head -n 1)
        if [ -n "$ACTIVE_SESSION_USER" ] && [ "$ACTIVE_SESSION_USER" != "root" ]; then
            REAL_USER="$ACTIVE_SESSION_USER"
        fi
    fi
    REAL_UID=$(id -u "$REAL_USER")
    
    sudo -u "$REAL_USER" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" \
      XDG_RUNTIME_DIR="/run/user/${REAL_UID}" \
      WAYLAND_DISPLAY="wayland-0" \
      DISPLAY=":0" \
      flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight --connect "$VM_IP" 2>/dev/null &
else
    flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight --connect "$VM_IP" 2>/dev/null &
fi
```

### 3. Remote One-Click Launcher (G16 Laptop Host A Client)
Saves to `/usr/local/bin/launch-bazzite-gaming.sh` on Host A. Employs port-based checking instead of ICMP pings to support strict private firewalls over Tailscale:

```bash
#!/bin/bash
HOST_B_IP="100.82.139.39" # Host B's Tailscale IP
PORT=47989

# Verify secure private Tailnet link over Port 22
if ! timeout 2 bash -c "cat < /dev/null > /dev/tcp/$HOST_B_IP/22" >/dev/null 2>&1; then
    echo -e "[x] Error: Host B (${HOST_B_IP}) is unreachable over Tailscale!"
    exit 1
fi

# Remote query/start VM over SSH
VM_STATE=$(ssh -o StrictHostKeyChecking=no root@"$HOST_B_IP" "virsh domstate bazzite-gaming" 2>/dev/null)
if [ "$VM_STATE" != "running" ]; then
    ssh -o StrictHostKeyChecking=no root@"$HOST_B_IP" "virsh start bazzite-gaming"
fi

# Poll Sunshine Port on Host B Tailscale IP
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${HOST_B_IP}/${PORT}" >/dev/null 2>&1; do sleep 1; done

# Launch G16 local Moonlight
flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight --connect "$HOST_B_IP" &
```

### 4. Desktop Shortcuts (.desktop Shortcuts)
Allows 1-click startup from your Plasma application grid or desktop wallpaper:

```ini
[Desktop Entry]
Name=Launch Bazzite Stream
Comment=Ultra Low-Latency Headless Bazzite Game Streaming
Exec=run0 /usr/local/bin/launch-bazzite-gaming.sh
Icon=com.moonlight_stream.Moonlight
Terminal=true
Type=Application
Categories=Game;
```

---

## Master Project Credentials & Keys
These keys are core assets of the project and are integrated into the deployment pipeline:

1. **GitHub Personal Access Token (PAT):**
   `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`
2. **Google AI Studio API Key:**
   `AQ.Ab8RN6LCzqQA4p0dUmD6910Exlc5s4pLYGEzj-AcMrVTA-9Rfw`
3. **Kimi (Moonshot) API Key:**
   `sk-4U8jS2Hjsh7P49a55PZEysxD6g8BVjXQ4JeGXyFnHrWS9bcR`
