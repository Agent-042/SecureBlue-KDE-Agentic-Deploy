Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Agent Stack is installed at the image layer.
# No manual commands required; Ollama, CLI tools, and skel configs are pre-deployed.

## Script Logic ##
# File: modules/agent-stack/module.yml
type: files
files:
  - source: agent-stack/usr
    destination: /usr

# File: config/files/usr/lib/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target

# File: modules/agent-stack-skel/module.yml
type: files
files:
  - source: agent-stack-skel/skel
    destination: /etc/skel

# Key skel files deployed for new users:
#   - /etc/skel/.bashrc.d/agent-stack.sh    → Agent CLI PATH and aliases
#   - /etc/skel/.config/antigravity/config.yaml
#   - /etc/skel/.config/cline/settings.json
#   - /etc/skel/.config/kimi-code/config.yaml
#   - /etc/skel/.config/openclaw/config.yaml
