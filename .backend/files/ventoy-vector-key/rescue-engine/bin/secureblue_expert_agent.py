#!/usr/bin/env python3
"""
SecureBlue KDE Offline Expert Agent & RAG Knowledge Engine
Comprehensive CLI expert system for SecureBlue, Kinoite, uBlue, Plasma 6, SELinux, and VFIO passthrough.
"""

import sys, os, json, argparse

EXPERT_KNOWLEDGE_BASE = {
    "rpm-ostree": {
        "description": "Atomic image-based package and deployment manager for Fedora Kinoite / SecureBlue.",
        "commands": {
            "status": "rpm-ostree status -v (Display active OCI/OSTree deployments and pending reboot changes)",
            "kargs": "sudo rpm-ostree kargs --append='amd_iommu=on iommu=pt' (Modify kernel boot parameters)",
            "rollback": "sudo rpm-ostree rollback (Revert to previous booted deployment state)",
            "override": "sudo rpm-ostree override replace <rpm_file> (Replace core RPM package in deployment)"
        }
    },
    "bootc": {
        "description": "Bootable Container engine for OCI-native system updates.",
        "commands": {
            "status": "bootc status (Check active OCI container image boot status)",
            "switch": "sudo bootc switch ghcr.io/secureblue/kinoite-nvidia-main-hardened:latest (Switch base OCI image)",
            "upgrade": "sudo bootc upgrade (Fetch and apply pending OCI container layer updates)"
        }
    },
    "selinux": {
        "description": "Security-Enhanced Linux access control policy management.",
        "commands": {
            "checkmodule": "checkmodule -M -m -o mod.mod mod.te (Compile TE policy source into module file)",
            "semodule_package": "semodule_package -o mod.pp -m mod.mod (Package module into deployable binary)",
            "semodule": "sudo semodule -i mod.pp (Install policy module into kernel policy store)",
            "restorecon": "sudo restorecon -R -v /path/to/dir (Restore default SELinux security contexts)"
        }
    },
    "vfio": {
        "description": "Virtual Function I/O framework for secondary GPU hardware passthrough.",
        "commands": {
            "unbind": "echo '0000:01:00.0' | sudo tee /sys/bus/pci/devices/0000:01:00.0/driver/unbind",
            "bind": "echo '0000:01:00.0' | sudo tee /sys/bus/pci/drivers/vfio-pci/bind",
            "check": "lspci -nnk -d 10de: | grep -i 'Kernel driver in use'"
        }
    },
    "kde_plasma6": {
        "description": "KDE Plasma 6 Wayland desktop configuration and styling tools.",
        "commands": {
            "lookandfeel": "plasma-apply-lookandfeel -a org.kde.breezedark.desktop (Apply Plasma 6 global theme)",
            "config": "kwriteconfig6 --file kdeglobals --group General --key AccentColor '10,132,255' (Set accent color)",
            "restart": "kquitapp6 plasmashell && kstart plasmashell (Restart Plasma 6 desktop shell)"
        }
    },
    "hid_injector": {
        "description": "Airgapped USB HID keystroke injection for headless recovery and OTP entry.",
        "commands": {
            "type": "python3 /rescue-engine/bin/hid_keystroke_injector.py --text 'systemctl reboot' --wpm 120",
            "otp": "bash /rescue-engine/bin/otp_keystroke_injector.sh 'rpm-ostree kargs' 120"
        }
    }
}

def search_expert_rag(query):
    query_lower = query.lower()
    print(f"\n==================================================")
    print(f"🤖 SECUREBLUE KDE EXPERT RAG: QUERY: '{query}'")
    print(f"==================================================")
    
    matches = []
    for topic, data in EXPERT_KNOWLEDGE_BASE.items():
        score = 0
        if topic in query_lower:
            score += 5
        if any(w in data["description"].lower() for w in query_lower.split()):
            score += 2
            
        for cmd, usage in data["commands"].items():
            if any(w in usage.lower() for w in query_lower.split()):
                score += 3
                
        if score > 0:
            matches.append((score, topic, data))
            
    matches.sort(key=lambda x: x[0], reverse=True)
    
    if not matches:
        # Fallback to general listing
        matches = [(1, t, d) for t, d in EXPERT_KNOWLEDGE_BASE.items()]
        
    for score, topic, data in matches[:3]:
        print(f"\n📌 TOPIC: {topic.upper()}")
        print(f"   Description: {data['description']}")
        print(f"   Key CLI Commands:")
        for cmd_name, cmd_usage in data["commands"].items():
            print(f"   • {cmd_name:12}: {cmd_usage}")
            
    print("\n==================================================")

def main():
    parser = argparse.ArgumentParser(description="SecureBlue KDE Offline Expert Agent")
    parser.add_argument("query", nargs="?", default="rpm-ostree kernel arguments and selinux", help="Query topic")
    args = parser.parse_args()
    
    search_expert_rag(args.query)

if __name__ == "__main__":
    main()
