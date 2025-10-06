#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Argo CD and app-of-apps

REPO_URL=${REPO_GIT_URL:-"https://github.com/balalaika7771/GR-infra.git"}
ARGOCD_DOMAIN=${ARGOCD_DOMAIN:-"argocd.185.176.94.66.nip.io"}

echo "[1/2] Applying Argo CD bootstrap (namespace, install, ingress, app-of-apps)..."
kubectl apply -k ./bootstrap

echo "[2/2] Waiting for Argo CD server to be ready..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m

echo "Argo CD is available at: https://${ARGOCD_DOMAIN}"
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

echo "Done. Argo CD will sync Applications from ${REPO_URL} (branch main)."

