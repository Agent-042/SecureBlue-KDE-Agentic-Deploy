#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "gen-lang-client-0385466726")
REGION="us-central1"
SERVICE_NAME="agy-cloudrun-mcp"

echo "[+] Enabling required Google Cloud APIs for project ${PROJECT_ID}..."
gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    aiplatform.googleapis.com \
    --project="${PROJECT_ID}"

echo "[+] Deploying Cloud Run MCP Server..."
# Deploying directly from Google's official cloud-run-mcp container/repo
gcloud run deploy ${SERVICE_NAME} \
    --image="gcr.io/cloudrun/mcp-server:latest" \
    --region=${REGION} \
    --platform=managed \
    --no-allow-unauthenticated \
    --set-env-vars="GCP_PROJECT=${PROJECT_ID}" \
    --project="${PROJECT_ID}"

echo "[+] Deployment successful. Obtaining service URL..."
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform=managed --region=${REGION} --project="${PROJECT_ID}" --format='value(status.url)')

echo "[+] MCP Server active at: ${SERVICE_URL}"
echo "[+] Local Proxy connection command:"
echo "    gcloud run services proxy ${SERVICE_NAME} --port=8080 --region=${REGION} --project=${PROJECT_ID}"
