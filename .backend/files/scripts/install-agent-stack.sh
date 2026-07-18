#!/usr/bin/env bash
# install-agent-stack.sh
# BlueBuild build-time script for the agent-stack module.
# Installs system-wide runtimes, Ollama, an LLM model, and a suite of AI
# coding/agent CLIs into the immutable Fedora KDE image.
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[agent-stack] $*"; }
warn() { echo "[agent-stack] WARNING: $*" >&2; }

# Print a message and keep going. Used at the top level so the whole build
# does not abort when an optional tool is unavailable.
continue_on_error() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    warn "$* (exit $rc)"
  fi
  return 0
}

# Create a tiny fallback wrapper that prints a helpful message and exits 1.
write_fallback_wrapper() {
  local target="$1"
  local message="$2"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "ERROR: $message" >&2
echo "This tool could not be installed during image build." >&2
echo "Install it manually or check the build logs for details." >&2
exit 1
EOF
  chmod +x "$target"
}

TMPDIR_STACK=$(mktemp -d)
trap 'rm -rf "${TMPDIR_STACK}"' EXIT

# ---------------------------------------------------------------------------
# 1. System-wide runtimes and build dependencies
# ---------------------------------------------------------------------------
log "Installing runtimes and build dependencies..."

# Ensure npm can install global packages when running as root in the build.
npm config set unsafe-perm true || true

rpm-ostree install -y \
  nodejs npm \
  python3.12 python3.12-pip \
  golang \
  git make gcc gcc-c++ \
  curl wget ca-certificates \
  || continue_on_error "rpm-ostree base package install failed"

# Fedora may ship an older Node. If node is missing or < 22, pull NodeSource 22.x.
node_major() {
  node --version 2>/dev/null | cut -d. -f1 | tr -d 'v' || echo 0
}
if ! command -v node >/dev/null 2>&1 || [[ "$(node_major)" -lt 22 ]]; then
  log "Node.js 22+ not satisfied; attempting NodeSource 22.x repository..."
  curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    || warn "NodeSource setup script failed."
  rpm-ostree install -y nodejs \
    || warn "NodeSource Node.js install failed; image may lack Node 22+."
fi

# Verify Python 3.12+
if ! command -v python3.12 >/dev/null 2>&1; then
  warn "python3.12 not available after install."
fi

# ---------------------------------------------------------------------------
# 2. Ollama binary
# ---------------------------------------------------------------------------
log "Installing Ollama binary..."

OLLAMA_VERSION=$(curl -fsSL https://api.github.com/repos/ollama/ollama/releases/latest \
  | grep -oP '"tag_name": "\K[^"]+' \
  || echo "")

if [[ -z "${OLLAMA_VERSION}" ]]; then
  OLLAMA_VERSION="v0.5.7"
  warn "Could not detect latest Ollama release; falling back to ${OLLAMA_VERSION}."
fi

OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64"
log "Downloading Ollama ${OLLAMA_VERSION} from ${OLLAMA_URL}..."

curl -fsSL --retry 3 --retry-delay 2 "${OLLAMA_URL}" -o /usr/bin/ollama \
  || continue_on_error "Ollama binary download failed"

if [[ -f /usr/bin/ollama ]]; then
  chmod +x /usr/bin/ollama
  /usr/bin/ollama --version 2>/dev/null || true
else
  warn "Ollama binary missing; skipping model pull and service setup."
fi

# ---------------------------------------------------------------------------
# 3. Ollama model directory and service user
# ---------------------------------------------------------------------------
log "Creating Ollama directories and service user..."

mkdir -p /usr/share/ollama/models

if ! getent group ollama >/dev/null 2>&1; then
  groupadd -r ollama || warn "Could not create ollama group."
fi

if ! getent passwd ollama >/dev/null 2>&1; then
  useradd -r -g ollama -d /usr/share/ollama -s /sbin/nologin \
    -c "Ollama service account" ollama \
    || warn "Could not create ollama user."
fi

chown -R ollama:ollama /usr/share/ollama || warn "Could not chown /usr/share/ollama."
chmod 755 /usr/share/ollama

# Install the static systemd service template shipped with this module.
if [[ -f /tmp/files/agent-stack/usr/lib/systemd/system/ollama.service ]]; then
  install -Dm644 /tmp/files/agent-stack/usr/lib/systemd/system/ollama.service \
    /usr/lib/systemd/system/ollama.service
else
  log "Writing inline ollama.service..."
  cat > /usr/lib/systemd/system/ollama.service <<'EOF'
[Unit]
Description=Ollama Service
Documentation=https://ollama.com
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ollama
Group=ollama
Environment="OLLAMA_MODELS=/usr/share/ollama/models"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="HOME=/usr/share/ollama"
ExecStart=/usr/bin/ollama serve
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
fi

# ---------------------------------------------------------------------------
# 4. Pull model during build
# ---------------------------------------------------------------------------
if [[ -x /usr/bin/ollama ]]; then
  log "Starting temporary Ollama server for model pull..."

  export OLLAMA_MODELS=/usr/share/ollama/models
  export OLLAMA_HOST=127.0.0.1:11434

  ollama serve >"${TMPDIR_STACK}/ollama-serve.log" 2>&1 &
  OLLAMA_PID=$!

  # Wait up to 90 seconds for the API to respond.
  server_ready=0
  for i in $(seq 1 90); do
    if curl -fsSL http://127.0.0.1:11434/ >/dev/null 2>&1; then
      server_ready=1
      break
    fi
    sleep 1
  done

  if [[ "${server_ready}" -eq 1 ]]; then
    log "Ollama server ready; pulling qwen2.5-coder:7b-instruct-q4_K_M..."
    ollama pull qwen2.5-coder:7b-instruct-q4_K_M \
      || warn "Model pull failed; model will need to be pulled at runtime."
  else
    warn "Ollama server did not become ready; skipping model pull."
    cat "${TMPDIR_STACK}/ollama-serve.log" >&2 || true
  fi

  if kill "${OLLAMA_PID}" 2>/dev/null; then
    wait "${OLLAMA_PID}" 2>/dev/null || true
  fi
else
  warn "Ollama binary not executable; skipping model pull."
fi

# ---------------------------------------------------------------------------
# 5. Cline CLI
# ---------------------------------------------------------------------------
log "Installing Cline CLI..."
npm install -g cline \
  || warn "Cline CLI install via npm failed."

# ---------------------------------------------------------------------------
# 6. Kimi Code CLI
# ---------------------------------------------------------------------------
log "Installing Kimi Code CLI..."

KIMI_INSTALL_DIR="/opt/kimi-code"
mkdir -p "${KIMI_INSTALL_DIR}"

# Some installers respect an install-directory env var; try a few common ones.
KIMI_CODE_INSTALL_DIR="${KIMI_INSTALL_DIR}" \
INSTALL_DIR="${KIMI_INSTALL_DIR}" \
  bash -c 'curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash' \
  || warn "Kimi Code CLI install script failed."

# Locate the binary wherever the installer placed it and move/link it into a
# predictable system location.
KIMI_BIN=""
for loc in \
  "${KIMI_INSTALL_DIR}/kimi" \
  /usr/local/bin/kimi \
  /usr/bin/kimi \
  /root/.local/bin/kimi \
  "${HOME}/.local/bin/kimi"
do
  if [[ -x "${loc}" ]]; then
    KIMI_BIN="${loc}"
    break
  fi
done

if [[ -n "${KIMI_BIN}" ]]; then
  if [[ "${KIMI_BIN}" != "${KIMI_INSTALL_DIR}/kimi" ]]; then
    cp -a "${KIMI_BIN}" "${KIMI_INSTALL_DIR}/kimi"
  fi
  ln -sf "${KIMI_INSTALL_DIR}/kimi" /usr/bin/kimi
  log "Kimi Code CLI available at /usr/bin/kimi"
else
  warn "Kimi Code CLI binary not found after install."
fi

# ---------------------------------------------------------------------------
# 7. OpenClaw
# ---------------------------------------------------------------------------
log "Installing OpenClaw..."

OPENCLAW_OK=0
if npm install -g openclaw 2>/dev/null; then
  OPENCLAW_OK=1
  log "OpenClaw installed via npm."
else
  warn "npm install -g openclaw failed; attempting GitHub build..."
  OPENCLAW_SRC="${TMPDIR_STACK}/openclaw"
  if git clone --depth 1 https://github.com/openclaw/openclaw.git "${OPENCLAW_SRC}" 2>/dev/null; then
    if (cd "${OPENCLAW_SRC}" && npm install && npm run build && npm link); then
      OPENCLAW_OK=1
      log "OpenClaw built and linked from GitHub."
    else
      warn "OpenClaw GitHub build failed."
    fi
  else
    warn "OpenClaw repository clone failed."
  fi
fi

if [[ "${OPENCLAW_OK}" -eq 0 ]] || ! command -v openclaw >/dev/null 2>&1; then
  write_fallback_wrapper /usr/bin/openclaw \
    "OpenClaw is not available. 'npm install -g openclaw' and the GitHub build both failed."
  warn "OpenClaw fallback wrapper installed."
fi

# ---------------------------------------------------------------------------
# 8. Antigravity CLI
# ---------------------------------------------------------------------------
log "Installing Antigravity CLI..."

ANTIGRAVITY_DIR="/opt/antigravity"
mkdir -p "${ANTIGRAVITY_DIR}"

INSTALL_DIR="${ANTIGRAVITY_DIR}" \
ANTIGRAVITY_INSTALL_DIR="${ANTIGRAVITY_DIR}" \
  bash -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash' \
  || warn "Antigravity CLI install script failed."

# Try to locate the binary and link it.
AGY_BIN=""
for loc in \
  "${ANTIGRAVITY_DIR}/agy" \
  "${ANTIGRAVITY_DIR}/bin/agy" \
  /usr/local/bin/agy \
  /usr/bin/agy \
  /root/.local/bin/agy \
  "${HOME}/.local/bin/agy"
do
  if [[ -x "${loc}" ]]; then
    AGY_BIN="${loc}"
    break
  fi
done

if [[ -n "${AGY_BIN}" ]]; then
  if [[ "${AGY_BIN}" != /usr/bin/agy ]]; then
    cp -a "${AGY_BIN}" /usr/bin/agy || true
  fi
  log "Antigravity CLI available at /usr/bin/agy"
else
  write_fallback_wrapper /usr/bin/agy \
    "Antigravity CLI is not available. The installer at https://antigravity.google/cli/install.sh failed or is unreachable."
  warn "Antigravity CLI fallback wrapper installed."
fi

# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------
log "Agent stack installation complete."
