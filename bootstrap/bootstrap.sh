#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f bootstrap/00-namespace.yaml

# Установка Argo CD через официальный install.yaml с фиксированной версией
curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml | kubectl apply -f -

kubectl apply -f bootstrap/20-argocd-ingress.yaml

echo "Argo CD установлен. Проверь IP ingress-nginx или LB и настрой DNS для ARGOCD_DOMAIN."


