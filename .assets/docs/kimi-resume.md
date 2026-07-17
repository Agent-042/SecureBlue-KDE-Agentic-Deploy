Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Kimi Resume helper clones the repository and verifies CLI availability.
# No manual commands required; it runs automatically on first login if needed.

## Script Logic ##
# File: modules/kimi-resume/module.yml
type: files
files:
  - source: kimi-resume/usr
    destination: /usr

# File: config/files/usr/bin/kimi-resume.sh
#!/bin/bash
# Resumes Kimi Code CLI session by cloning the repo and verifying setup
REPO_URL="https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy.git"
WORKSPACE="${HOME}/Workspace/SecureBlue-KDE-Agentic-Deploy"
if [ ! -d "${WORKSPACE}" ]; then
  git clone "${REPO_URL}" "${WORKSPACE}"
fi
cd "${WORKSPACE}"
# Verify CLI tools are available
which kimi-code || echo "kimi-code not found in PATH"
