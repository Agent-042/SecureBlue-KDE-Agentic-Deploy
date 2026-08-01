# Agent stack shell defaults for SecureBlue KDE Agentic Deploy.
#
# Ollama is baked into the image as a system binary and started by the
# ollama.service on boot. It exposes a local API on http://127.0.0.1:11434.

export OLLAMA_HOST="http://127.0.0.1:11434"

# Convenience aliases for the agent CLI toolchain.
# These are intentionally simple placeholders; customize them here if you
# want wrapper behavior (e.g., default flags or logging).
alias agy='agy'
alias cline='cline'
alias kimi='kimi'
alias openclaw='openclaw'
