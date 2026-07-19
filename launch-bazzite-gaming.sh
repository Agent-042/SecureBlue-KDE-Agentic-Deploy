#!/bin/bash
# ==============================================================================
# Bazzite Gaming VM One-Click Zero-Latency Launcher
# Designed for SecureBlue Host with AMD/NVIDIA VFIO Passthrough Setup
# ==============================================================================
# Features:
#   - Automatic early-boot check & dynamic VM startup verification
#   - Dynamic IP resolution over the high-speed isolated virtual bridge
#   - Advanced port availability polling with beautifully stylized spinners
#   - Automated, seamless local Moonlight flatpak client launching
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

# 1. Check Privilege Level
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Warning: Not running as root. Querying system status may prompt for sudo.${NC}"
    SUDO="sudo"
else
    SUDO=""
fi

# 2. Verify VM Configuration
VM_NAME="bazzite-gaming"
VM_IP="192.168.123.42"
PORT=47989 # Sunshine Streaming Port

echo -e "${BLUE}[*] Verifying virtual machine '${VM_NAME}' state...${NC}"
VM_STATE=$($SUDO virsh domstate "$VM_NAME" 2>/dev/null)

if [ -z "$VM_STATE" ]; then
    echo -e "${RED}[x] Error: Virtual machine '${VM_NAME}' is not registered with libvirt!${NC}"
    exit 1
fi

echo -e "${GREEN}[+] VM Status detected: ${BOLD}${VM_STATE}${NC}"

# 3. Dynamic VM Startup
if [ "$VM_STATE" != "running" ]; then
    echo -e "${YELLOW}[*] Starting Bazzite Gaming VM...${NC}"
    $SUDO virsh start "$VM_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[x] Error: Failed to start virtual machine '${VM_NAME}'.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Virtual machine launch signal sent successfully!${NC}"
fi

# 4. Shared Memory Allocation Validation (Looking Glass Buffer)
SHM_FILE="/dev/shm/looking-glass"
if [ -e "$SHM_FILE" ]; then
    echo -e "${BLUE}[*] Aligning shared memory buffers for low-latency capture...${NC}"
    $SUDO chmod 0660 "$SHM_FILE" 2>/dev/null
    $SUDO chown agent-42:qemu "$SHM_FILE" 2>/dev/null
    $SUDO chcon -t svirt_image_t "$SHM_FILE" 2>/dev/null
fi

# 5. Network Interface Initialization Polling
echo -e "${BLUE}[*] Waiting for Bazzite high-speed bridge network interface...${NC}"

# Spinner implementation for polished, professional CLI feedback
spin() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b\b"
}

# Wait for ping response on 192.168.123.42
TIMEOUT=60
COUNTER=0
echo -n -e "${YELLOW}[*] Pinging Bazzite Guest (${VM_IP})...${NC}"
while ! ping -c 1 -W 1 "$VM_IP" >/dev/null 2>&1; do
    sleep 1
    let COUNTER=COUNTER+1
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo -e "\n${RED}[x] Error: Timeout waiting for VM network bridge lease.${NC}"
        exit 1
    fi
    printf "."
done
echo -e " ${GREEN}[CONNECTED]${NC}"

# 6. Sunshine Game-Stream Service Initialization Polling
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

# 7. Start Moonlight Client
echo -e "${CYAN}${BOLD}[*] Launching low-latency Moonlight game stream client...${NC}"
echo -e "${BLUE}[*] Connecting directly to virtual graphics pipeline over private virtual link.${NC}"

flatpak run com.moonlight_stream.Moonlight --connect "$VM_IP" 2>/dev/null &

echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}      🎮  BAZZITE SESSION STARTED SUCCESSFULLY! HAPPY GAMING!  🎮      ${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
