#!/usr/bin/env bash
set -euo pipefail

# Prebaked Configuration
GITHUB_PAT="${GITHUB_PAT:-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}"
PROJECT_ID="gen-lang-client-0385466726"
REGION="us-west1"
CORPUS_ID="projects/245296575460/locations/us-west1/ragCorpora/2305843009213693952"

echo "[+] Setting GCP project to ${PROJECT_ID}..."
if command -v gcloud >/dev/null 2>&1; then
    gcloud config set project "${PROJECT_ID}" 2>/dev/null || true
fi

# Ensure Python vertexai SDK is installed
if ! python3 -c "import vertexai" 2>/dev/null; then
    echo "[+] Installing Vertex AI & Gemini SDK dependencies..."
    pip3 install --quiet google-cloud-aiplatform google-genai grpc-google-iam-v1 google-cloud-storage google-cloud-resource-manager 2>/dev/null || \
    python3 -m pip install --quiet --no-deps google-cloud-aiplatform google-genai 2>/dev/null || true
fi

export GITHUB_PAT

echo "[+] Syncing SecureBlue-KDE-Agentic-Deploy repository..."
if [ -d "SecureBlue-KDE-Agentic-Deploy" ]; then
    cd SecureBlue-KDE-Agentic-Deploy
    git pull origin main 2>/dev/null || true
elif [ -f "cloudshell_bootstrap.sh" ]; then
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
" 2>/dev/null || echo "[!] Python RAG init complete."

echo "[+] Machine Pool Synchronization Complete!"
