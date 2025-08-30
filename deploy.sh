#!/bin/bash

# Minecraft Infrastructure Deployment Script
# Supports Kubernetes (OrbStack) with full cleanup capabilities
# Uses NodePort architecture for stable external access

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования с красивым форматированием
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Конфигурация
NAMESPACE="minecraft"
HELM_DIR="helm"


# Проверка зависимостей
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes cluster is not accessible"
        exit 1
    fi
    
    success "All dependencies verified"
}

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    MINECRAFT INFRASTRUCTURE DEPLOYMENT"
    echo "================================================================================"
    echo ""
    echo "DESCRIPTION:"
    echo "  Automated deployment script for Minecraft infrastructure on Kubernetes"
    echo "  Uses NodePort architecture for stable external access"
    echo ""
    echo "USAGE: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h     Show this help message"
    echo "  --cleanup      Remove all deployments from cluster"
    echo ""
    echo "EXAMPLES:"
    echo "  $0              Deploy infrastructure"
    echo "  $0 --cleanup    Clean up all deployments"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Kubernetes cluster (OrbStack, minikube, etc.)"
    echo "  - kubectl configured and connected to cluster"
    echo "  - helm installed"
    echo "  - Internet access for image downloads"
    echo ""
    echo "COMPONENTS:"
    echo "  - PostgreSQL (Database)"
    echo "  - Redis (Cache & Queues)"
    echo "  - Velocity (Minecraft Proxy) - NodePort:30000"
    echo "  - Purpur (Minecraft Server)"
    echo "  - Economy API (Microservice)"
    echo ""
    echo "PORTS:"
    echo "  - Velocity: 30000 (External NodePort)"
    echo "  - Economy API: 8080 (Internal)"
    echo "  - PostgreSQL: 5432 (Internal)"
    echo "  - Redis: 6379 (Internal)"
    echo ""
    echo "ARCHITECTURE:"
    echo "  - NodePort Service for stable external access"
    echo "  - No port-forward required"
    echo "  - Automatic recovery and scaling"
    echo "  - Kubernetes native design"
    echo "================================================================================"
}

# Очистка развертываний
cleanup() {
    echo ""
    echo "================================================================================"
    echo "                           ПОЛНАЯ ОЧИСТКА КЛАСТЕРА"
    echo "================================================================================"
    echo ""
    
    log "Начинаю полную очистку кластера..."
    
    # Останавливаем все port-forward процессы
    log "Останавливаю все port-forward процессы..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 3
    
    # Удаляем все Helm релизы
    log "Удаляю Helm релизы..."
    helm uninstall purpur-lobby -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall velocity -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall economy-api -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall redis -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall postgres -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall registry -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    success "Helm релизы удалены"
    
    # Ждем завершения удаления Helm релизов
    log "Ожидаю завершения удаления Helm релизов..."
    sleep 10
    
    # Удаляем все ресурсы из namespace
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log "Удаляю все ресурсы из namespace $NAMESPACE..."
        
        # Удаляем deployments
        kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем services
        kubectl delete service --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем pods
        kubectl delete pod --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем PVC
        kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем ConfigMaps
        kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем namespace
        log "Удаляю namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        success "Namespace $NAMESPACE удален"
    else
        log "Namespace $NAMESPACE не найден, пропускаю"
    fi
    
    # Ждем полного удаления и очищаем кэш
    log "Ожидаю завершения очистки..."
    sleep 15
    
    # Очищаем Docker образы если они есть
    log "Очищаю Docker образы..."
    docker rmi localhost:30500/economy-api:latest 2>/dev/null || true
    docker rmi localhost:30500/economy-plugin:latest 2>/dev/null || true
    
    echo ""
    echo "================================================================================"
    echo "  КЛАСТЕР ПОЛНОСТЬЮ ОЧИЩЕН"
    echo "  Все развертывания удалены из кластера"
    echo "================================================================================"
    echo ""
}

# Основная функция развертывания
deploy() {
    echo ""
    echo "================================================================================"
    echo "                    DEPLOYING MINECRAFT INFRASTRUCTURE"
    echo "================================================================================"
    echo ""
    
    log "Starting deployment process..."
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем namespace
    log "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    success "Namespace $NAMESPACE created"
    
    # Устанавливаем Helm chart: registry
    log "Installing Helm chart: registry"
    helm upgrade --install registry ./helm/registry -n "$NAMESPACE" --wait --timeout=180s
    success "Registry deployed"
    
    # Развертываем PostgreSQL
    log "Deploying PostgreSQL..."
    helm upgrade --install postgres $HELM_DIR/postgres \
        --namespace $NAMESPACE \
        --set persistence.storageClass=local-path \
        --wait --timeout=600s
    success "PostgreSQL deployed"
    
    # Развертываем Redis
    log "Deploying Redis..."
    helm upgrade --install redis $HELM_DIR/redis \
        --namespace $NAMESPACE \
        --wait
    success "Redis deployed"
    
    # Ждем готовности баз данных
    log "Waiting for PostgreSQL readiness..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n $NAMESPACE --timeout=600s
    
    # Дополнительная проверка готовности PostgreSQL
    log "Verifying PostgreSQL connection..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if kubectl exec -n $NAMESPACE deployment/postgres -- pg_isready -U minecraft -d minecraft &>/dev/null; then
            success "PostgreSQL is ready"
            break
        fi
        log "PostgreSQL not ready yet, waiting... (attempt $((retries+1))/30)"
        sleep 10
        retries=$((retries+1))
    done
    
    if [ $retries -eq 30 ]; then
        error "PostgreSQL did not become ready within timeout"
        exit 1
    fi
    
    # Создаем базы данных (они уже созданы через initScripts в Helm чарте)
    log "Checking databases auth_bridge and economy_api..."
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "\\l" | grep -E "(auth_bridge|economy_api)" || {
        warning "Databases not found, creating them..."
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE auth_bridge;" 2>/dev/null || true
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE economy_api;" 2>/dev/null || true
    }
    success "Databases ready"
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n $NAMESPACE --timeout=300s
    success "Redis ready"
    
    # Развертываем Velocity
    log "Deploying Velocity proxy..."
    helm upgrade --install velocity $HELM_DIR/velocity \
        --namespace $NAMESPACE \
        --wait
    success "Velocity deployed"
    
    # Настройка доступа к Velocity
    log "Configuring Velocity access..."
    
    # Получаем информацию о NodePort сервисе
    log "Checking NodePort service..."
    NODE_PORT=$(kubectl get svc velocity -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$NODE_PORT" ]; then
        success "Velocity configured on NodePort: $NODE_PORT"
        success "Server accessible at localhost:$NODE_PORT"
    else
        warning "NodePort not configured, check service: kubectl get svc velocity -n $NAMESPACE"
    fi
    
    # Развертываем Purpur
    log "Deploying Purpur shard..."
    helm upgrade --install purpur-lobby $HELM_DIR/purpur-shard \
        --namespace $NAMESPACE \
        --set persistence.storageClass=local-path \
        --wait --timeout=600s
    success "Purpur deployed"
    
    # Ждем готовности сервисов
    log "Waiting for services readiness..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velocity -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=purpur-shard -n $NAMESPACE --timeout=300s
    success "Services ready"
    
    # Первичная установка плагина в Purpur
    log "Installing Minecraft plugin (initial deployment)..."
    if ./upload-plugin.sh; then
        success "Plugin installed"
    else
        error "Failed to install plugin. Check logs and retry."
        exit 1
    fi
    
    # Развертываем economy-api через отдельный скрипт
    log "Deploying economy-api..."
    if ./deploy-economy-api.sh; then
        success "economy-api deployed"
    else
        warning "Failed to deploy economy-api. Run ./deploy-economy-api.sh manually."
    fi
    
    success "Deployment completed successfully!"
    
    # Получаем информацию о подключении
    echo ""
    echo "================================================================================"
    echo "                    MINECRAFT SERVER READY FOR CONNECTION"
    echo "================================================================================"
    echo ""
    if [ -n "$NODE_PORT" ]; then
        echo "  SERVER ADDRESS: localhost:$NODE_PORT"
        echo "  CONNECTION TYPE: NodePort Service (Stable)"
        echo "  STATUS: Ready"
        echo ""
        echo "  FEATURES:"
        echo "    - No port-forward required"
        echo "    - Fixed port number"
        echo "    - Automatic recovery"
        echo "    - Kubernetes native"
    else
        echo "  STATUS: Warning - NodePort not configured"
        echo "  ACTION: Check service status: kubectl get svc velocity -n $NAMESPACE"
    fi
    echo ""
    echo "================================================================================"
    echo "  NEXT STEPS:"
    echo "    1. Check pod status: kubectl get pods -n $NAMESPACE"
    echo "    2. Connect to server: localhost:$NODE_PORT"
    echo "    3. Upload plugin: ./upload-plugin.sh"
    echo ""
    echo "  USEFUL COMMANDS:"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=velocity"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "    kubectl get svc velocity -n $NAMESPACE"
    echo "================================================================================"
    echo ""

}

# Главная логика
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --cleanup)
            cleanup
            exit 0
            ;;
        "")
            deploy
            ;;
        *)
            error "Unknown option: $1"
            echo "Use $0 --help for usage information"
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
