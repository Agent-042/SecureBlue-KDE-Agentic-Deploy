#!/usr/bin/env bash
set -euo pipefail

# Retrieve PAT dynamically from GCP Secret Manager or environment
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "gen-lang-client-0385466726")

if command -v gcloud >/dev/null 2>&1; then
    GITHUB_PAT=$(gcloud secrets versions access latest --secret=github-pat-agy --project=${PROJECT_ID} 2>/dev/null || echo "${GITHUB_PAT:-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}")
else
    GITHUB_PAT="${GITHUB_PAT:-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}"
fi

REPO_OWNER="${1:-Agent-042}"
REPO_NAME="${2:-SecureBlue-KDE-Agentic-Deploy}"
BRANCH="${3:-main}"

echo "[+] Authenticating with GitHub via Secret Manager PAT for ${REPO_OWNER}/${REPO_NAME}..."
REMOTE_URL="https://x-access-token:${GITHUB_PAT}@github.com/${REPO_OWNER}/${REPO_NAME}.git"

# Initialize git if needed
if [ ! -d ".git" ]; then
    git init
    git branch -M ${BRANCH}
    git remote add origin ${REMOTE_URL}
else
    git remote set-url origin ${REMOTE_URL}
fi

echo "[+] Staging manifest, playbook, and deployment files..."
git add .

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT_MSG="[Agy-AutoSync] Automated infrastructure state backup (${TIMESTAMP})"

if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "[!] No changes to commit."
else
    git commit -m "${COMMIT_MSG}"
fi

echo "[+] Fetching and syncing with ${BRANCH}..."
git fetch origin ${BRANCH} 2>/dev/null || true
git rebase origin/${BRANCH} 2>/dev/null || git push -u origin ${BRANCH} --force

echo "[+] Pushing changes to ${BRANCH}..."
git push -u origin ${BRANCH}
echo "[+] Repository sync complete."
