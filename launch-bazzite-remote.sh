#!/bin/bash
# ==============================================================================
# Bazzite Gaming VM Remote Zero-Latency Launcher (G16 Laptop Client)
# Designed to boot the VM on Host B (AMD Workstation) and connect via Tailscale
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
echo -e "${BLUE}${BOLD}       🎮  BAZZITE GAMING REMOTE STREAM LAUNCHER (G16 CLIENT)  🎮        ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"

HOST_B_IP="100.82.139.39"  # Host B's Tailscale IP (Hypervisor)
VM_IP="100.85.147.119"     # Direct Tailscale IP of Bazzite Gaming VM
PORT=47989                 # Sunshine Port on Guest VM

# 1. Verify Tailscale Connectivity
echo -e "${BLUE}[*] Verifying secure private Tailnet link to Host B (${HOST_B_IP})...${NC}"
if ! timeout 2 bash -c "cat < /dev/null > /dev/tcp/$HOST_B_IP/22" >/dev/null 2>&1; then
    echo -e "${RED}[x] Error: Host B (${HOST_B_IP}) is unreachable over Tailscale!${NC}"
    echo -e "${YELLOW}[!] Action: Please verify that Tailscale is active and logged in on both devices.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Tailscale private tunnel: ${BOLD}ACTIVE${NC}"

# 2. Remotely query or start the Bazzite VM on Host B
echo -e "${BLUE}[*] Querying virtual machine status on Host B...${NC}"
VM_STATE=$(ssh -o StrictHostKeyChecking=no root@"$HOST_B_IP" "virsh domstate bazzite-gaming" 2>/dev/null)

if [ -z "$VM_STATE" ]; then
    echo -e "${RED}[x] Error: Failed to query VM state on Host B via SSH.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Host B VM Status: ${BOLD}${VM_STATE}${NC}"

if [ "$VM_STATE" != "running" ]; then
    echo -e "${YELLOW}[*] Starting Bazzite Gaming VM remotely on Host B...${NC}"
    ssh -o StrictHostKeyChecking=no root@"$HOST_B_IP" "virsh start bazzite-gaming"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[x] Error: Failed to start virtual machine on Host B.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] VM remote launch signal sent successfully!${NC}"
fi

# 3. Poll Sunshine stream daemon availability on Guest VM (over Tailscale)
TIMEOUT=60
COUNTER=0
echo -n -e "${YELLOW}[*] Polling Sunshine game-streaming port directly on VM (${VM_IP})...${NC}"
while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/${PORT}" >/dev/null 2>&1; do
    sleep 1
    let COUNTER=COUNTER+1
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo -e "\n${RED}[x] Error: Timeout waiting for Sunshine stream daemon on ${VM_IP}:${PORT}.${NC}"
        exit 1
    fi
    printf "."
done
echo -e " ${GREEN}[ACTIVE]${NC}"

# 4. Launch Moonlight Client on G16
echo -e "${CYAN}${BOLD}[*] Launching low-latency Moonlight client...${NC}"
echo -e "${BLUE}[*] Connecting directly to virtual graphics pipeline over Tailscale.${NC}"

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
    
    echo -e "${CYAN}[*] Routing graphical application execution to user context: ${REAL_USER} (UID ${REAL_UID})${NC}"
    runuser -l "$REAL_USER" -c "WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/${REAL_UID} flatpak run --env=LD_PRELOAD=\"\" com.moonlight_stream.Moonlight &"
else
    flatpak run --env=LD_PRELOAD="" com.moonlight_stream.Moonlight &
fi

echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}     🎮  BAZZITE REMOTE SESSION INITIALIZED! HAPPY GAMING!  🎮       ${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"
