#!/bin/bash
# ==============================================================================
# Bazzite Gaming VM One-Click Zero-Latency Launcher (Local Workstation Host)
# Designed for SecureBlue Host with AMD/NVIDIA VFIO Passthrough Setup
# ==============================================================================

# Stylized Terminal Output Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}        🎮  BAZZITE GAMING VM ONE-CLICK ULTRA-STREAM LAUNCHER  🎮        ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"

# Define VM parameters
VM_NAME="bazzite-gaming"
VM_IP="192.168.123.42"
PORT=47989 # Sunshine Streaming Port

# 1. Verify VM Configuration
echo -e "${BLUE}[*] Verifying virtual machine '${VM_NAME}' state...${NC}"
VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null)

if [ -z "$VM_STATE" ]; then
    echo -e "${RED}[x] Error: Virtual machine '${VM_NAME}' is not registered with libvirt!${NC}"
    exit 1
fi

echo -e "${GREEN}[+] VM Status detected: ${BOLD}${VM_STATE}${NC}"

# 2. Dynamic VM Startup
if [ "$VM_STATE" != "running" ]; then
    echo -e "${YELLOW}[*] Starting Bazzite Gaming VM...${NC}"
    virsh start "$VM_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[x] Error: Failed to start virtual machine '${VM_NAME}'.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Virtual machine launch signal sent successfully!${NC}"
fi

# 3. Shared Memory Allocation Validation (Looking Glass Buffer)
SHM_FILE="/dev/shm/looking-glass"
if [ -e "$SHM_FILE" ]; then
    echo -e "${BLUE}[*] Aligning shared memory buffers for low-latency capture...${NC}"
    chmod 0660 "$SHM_FILE" 2>/dev/null
    chown agent-042:qemu "$SHM_FILE" 2>/dev/null
    chcon -t svirt_image_t "$SHM_FILE" 2>/dev/null
fi

# 4. Network Interface Initialization Polling
echo -e "${BLUE}[*] Waiting for Bazzite high-speed bridge network interface...${NC}"

TIMEOUT=60
COUNTER=0
echo -n -e "${YELLOW}[*] Connecting to Bazzite Guest (${VM_IP}) on Port 22...${NC}"
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/22" >/dev/null 2>&1; do
    sleep 1
    let COUNTER=COUNTER+1
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo -e "\n${RED}[x] Error: Timeout waiting for VM network bridge lease.${NC}"
        exit 1
    fi
    printf "."
done
echo -e " ${GREEN}[CONNECTED]${NC}"

# 5. Sunshine Game-Stream Service Initialization Polling
echo -n -e "${YELLOW}[*] Waiting for Sunshine Game-Streaming Engine to initialize...${NC}"
COUNTER=0
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/${PORT}" >/dev/null 2>&1; do
    sleep 1
    let COUNTER=COUNTER+1
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo -e "\n${RED}[x] Error: Timeout waiting for Sunshine stream service on port ${PORT}.${NC}"
        exit 1
    fi
    printf "."
done
echo -e " ${GREEN}[ACTIVE]${NC}"

# 6. Start Moonlight Client (Ensuring clean user context and session execution)
echo -e "${CYAN}${BOLD}[*] Launching low-latency Moonlight game stream client...${NC}"
echo -e "${BLUE}[*] Connecting directly to virtual graphics pipeline over private virtual link.${NC}"

REAL_USER="agent-042"
REAL_UID=1000

if [ "$EUID" -eq 0 ]; then
    # Running as root (via sudo or run0). Detect the active non-root desktop user to route display.
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        REAL_USER="$SUDO_USER"
    else
        ACTIVE_SESSION_USER=$(loginctl list-sessions | grep -i active | awk '{print $3}' | head -n 1)
        if [ -n "$ACTIVE_SESSION_USER" ] && [ "$ACTIVE_SESSION_USER" != "root" ]; then
            REAL_USER="$ACTIVE_SESSION_USER"
        fi
    fi
    REAL_UID=$(id -u "$REAL_USER")
    
    echo -e "${CYAN}[*] Routing graphical application execution to user context: ${REAL_USER} (UID ${REAL_UID})${NC}"
    sudo -u "$REAL_USER" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${REAL_UID}/bus" \
      XDG_RUNTIME_DIR="/run/user/${REAL_UID}" \
      WAYLAND_DISPLAY="wayland-0" \
      DISPLAY=":0" \
      flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight &
else
    # Running natively as a regular user, run Moonlight directly
    flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight &
fi

echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}      🎮  BAZZITE SESSION STARTED SUCCESSFULLY! HAPPY GAMING!  🎮      ${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
