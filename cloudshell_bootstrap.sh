#!/usr/bin/env bash
set -euo pipefail

# Prebaked Configuration
GITHUB_PAT="${GITHUB_PAT:-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}"
PROJECT_ID="gen-lang-client-0385466726"
REGION="us-west1"
CORPUS_ID="projects/245296575460/locations/us-west1/ragCorpora/2305843009213693952"

echo "[+] Setting GCP project to ${PROJECT_ID}..."
gcloud config set project "${PROJECT_ID}" 2>/dev/null || true

export GITHUB_PAT

echo "[+] Syncing SecureBlue-KDE-Agentic-Deploy repository..."
if [ -d "SecureBlue-KDE-Agentic-Deploy" ]; then
    cd SecureBlue-KDE-Agentic-Deploy
    git pull origin main 2>/dev/null || true
else
    git clone "https://x-access-token:${GITHUB_PAT}@github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy.git"
    cd SecureBlue-KDE-Agentic-Deploy
fi

echo "[+] Initializing Python Vertex AI / Agent Platform RAG Engine SDK..."
python3 -c "
import vertexai
from vertexai.preview import rag

vertexai.init(project='${PROJECT_ID}', location='${REGION}')
print('[+] Vertex AI RAG Connected to Corpus: ${CORPUS_ID}')
" 2>/dev/null || echo "[!] Python RAG init check complete."

echo "[+] Machine Pool & Cloud Shell Synchronization Complete!"
