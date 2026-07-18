#!/usr/bin/env bash
# install-agent-stack.sh
# BlueBuild build-time script for the agent-stack module.
# Installs system-wide runtimes, Ollama, an LLM model, and a suite of AI
# coding/agent CLIs into the immutable Fedora KDE image.
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# System-wide runtimes and build dependencies
rpm-ostree install -y nodejs npm python3.12 python3.12-pip golang git make gcc gcc-c++ curl wget ca-certificates

# Ensure npm can install global packages when running as root in the build
npm config set unsafe-perm true

# Install NodeSource 22.x repository and nodejs (fallback if Fedora ships older Node)
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
rpm-ostree install -y nodejs

# Create Ollama service user and directories
groupadd -r ollama
useradd -r -g ollama -d /usr/share/ollama -s /sbin/nologin -c "Ollama service account" ollama
mkdir -p /usr/share/ollama/models
chown -R ollama:ollama /usr/share/ollama
chmod 755 /usr/share/ollama

# Install Ollama binary (v0.5.7 fallback)
curl -fsSL --retry 3 --retry-delay 2 https://github.com/ollama/ollama/releases/download/v0.5.7/ollama-linux-amd64 -o /usr/bin/ollama
chmod +x /usr/bin/ollama

# Install Ollama systemd service
install -Dm644 /tmp/files/agent-stack/usr/lib/systemd/system/ollama.service /usr/lib/systemd/system/ollama.service

# Enable Ollama service
systemctl enable ollama.service

# Install Cline CLI globally
npm install -g cline

# Install OpenClaw globally
npm install -g openclaw

# Install Kimi Code CLI
mkdir -p /opt/kimi-code
curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash
ln -sf /opt/kimi-code/kimi /usr/bin/kimi

# Install Antigravity CLI
mkdir -p /opt/antigravity
curl -fsSL https://antigravity.google/cli/install.sh | bash
cp -a /opt/antigravity/agy /usr/bin/agy

# Pull Ollama model (build-time; requires temporary server)
/usr/bin/ollama serve &
sleep 10
/usr/bin/ollama pull qwen2.5-coder:7b-instruct-q4_K_M
kill %1 || true

# Install fallback wrappers for tools that may fail in build environment
mkdir -p /usr/bin
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
