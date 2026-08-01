Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Local AI (Ollama) is pre-installed at the image layer.
# No manual commands required; the service starts automatically on boot.
# Users can interact with it via CLI or the agent stack tools.

run0 systemctl status ollama

ollama list

## Script Logic ##
# File: modules/local-ai/module.yml (generic)
type: files
files:
  - source: local-ai/usr
    destination: /usr

# File: modules/local-ai-intel-g16/module.yml (Intel-optimized for G16)
type: files
files:
  - source: local-ai-intel-g16/usr
    destination: /usr

# File: modules/local-ai-amd-workstation/module.yml (AMD-optimized)
type: files
files:
  - source: local-ai-amd-workstation/usr
    destination: /usr

# File: config/files/usr/share/containers/systemd/ollama.container
[Container]
Image=docker.io/ollama/ollama:latest
PublishPort=11434:11434
Volume=ollama:/root/.ollama

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
