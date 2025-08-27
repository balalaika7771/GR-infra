#!/bin/bash

# Единый скрипт развертывания Minecraft Infrastructure
# Поддерживает Kubernetes (OrbStack) и полную очистку

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Конфигурация
NAMESPACE="minecraft"
HELM_DIR="helm"
ISTIO_DIR="istio"

# Проверка зависимостей
check_dependencies() {
    log "Проверяем зависимости..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl не установлен"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm не установлен"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes кластер недоступен"
        exit 1
    fi
    
    success "Все зависимости проверены"
}

# Показать справку
show_help() {
    echo "Minecraft Infrastructure - Простой скрипт развертывания Kubernetes"
    echo ""
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --help, -h     Показать эту справку"
    echo "  --cleanup      Полная очистка всех развертываний"
    echo ""
    echo "Примеры:"
    echo "  $0              Развернуть инфраструктуру"
    echo "  $0 --cleanup    Очистить все развертывания"
    echo ""
    echo "Требования:"
    echo "  - Kubernetes кластер (OrbStack, minikube, etc.)"
    echo "  - kubectl настроен и подключен к кластеру"
    echo "  - helm установлен"
    echo "  - Доступ к интернету для загрузки образов"
    echo ""
    echo "Компоненты:"
    echo "  - PostgreSQL (база данных)"
    echo "  - Redis (кэш и очереди)"
    echo "  - Velocity (Minecraft прокси)"
    echo "  - Purpur (Minecraft сервер)"
    echo "  - Economy API (микросервис экономики)"
    echo ""
    echo "Порты:"
    echo "  - Velocity: 25565 (внешний)"
    echo "  - Economy API: 8080 (внутренний)"
    echo "  - PostgreSQL: 5432 (внутренний)"
    echo "  - Redis: 6379 (внутренний)"
}

# Очистка развертываний
cleanup() {
    log "Очистка развертываний..."
    
    # Удаляем Helm релизы
    helm uninstall economy-api -n $NAMESPACE 2>/dev/null || true
    helm uninstall purpur-lobby -n $NAMESPACE 2>/dev/null || true
    helm uninstall velocity -n $NAMESPACE 2>/dev/null || true
    helm uninstall redis -n $NAMESPACE 2>/dev/null || true
    helm uninstall postgres -n $NAMESPACE 2>/dev/null || true
    
    # Удаляем namespace
    kubectl delete namespace $NAMESPACE 2>/dev/null || true
    
    success "Очистка завершена"
}

# Основная функция развертывания
deploy() {
    log "Начинаем развертывание Minecraft Infrastructure..."
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем namespace
    log "Создание namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    success "Namespace $NAMESPACE создан"
    
    # Развертываем PostgreSQL
    log "Развертывание PostgreSQL..."
    helm install postgres $HELM_DIR/postgres \
        --namespace $NAMESPACE \
        --set postgresql.enabled=true \
        --set postgresql.postgresqlUsername=minecraft \
        --set postgresql.postgresqlPassword=minecraft123 \
        --set postgresql.postgresqlDatabase=minecraft \
        --wait
    success "PostgreSQL развернут"
    
    # Развертываем Redis
    log "Развертывание Redis..."
    helm install redis $HELM_DIR/redis \
        --namespace $NAMESPACE \
        --wait
    success "Redis развернут"
    
    # Ждем готовности баз данных
    log "Ожидание готовности баз данных..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n $NAMESPACE --timeout=300s
    
    # Создаем базы данных
    log "Создание баз данных auth_bridge и economy_api..."
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE auth_bridge;" 2>/dev/null || true
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE economy_api;" 2>/dev/null || true
    success "Базы данных созданы"
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n $NAMESPACE --timeout=300s
    success "Базы данных готовы"
    
    # Развертываем Velocity
    log "Развертывание Velocity прокси..."
    helm install velocity $HELM_DIR/velocity \
        --namespace $NAMESPACE \
        --wait
    success "Velocity развернут"
    
    # Развертываем Purpur
    log "Развертывание Purpur шарда..."
    helm install purpur-lobby $HELM_DIR/purpur-shard \
        --namespace $NAMESPACE \
        --wait
    success "Purpur развернут"
    
    # Развертываем economy-api
    log "Развертывание economy-api..."
    helm install economy-api $HELM_DIR/economy-api \
        --namespace $NAMESPACE \
        --wait
    success "economy-api развернут"
    
    # Ждем готовности сервисов
    log "Ожидание готовности сервисов..."
    kubectl wait --for=condition=available deployment/economy-api -n $NAMESPACE --timeout=300s
    success "Сервисы готовы"
    
    success "Развертывание завершено успешно!"
    
    echo ""
    echo "Следующие шаги:"
    echo "1. Проверьте статус подов: kubectl get pods -n $NAMESPACE"
    echo "2. Подключитесь к серверу: IP:25565"
    echo "3. Для загрузки плагина используйте: ./upload-plugin.sh"
    echo ""
    echo "Полезные команды:"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=velocity"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "  kubectl port-forward -n $NAMESPACE svc/velocity 25565:25565"
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
            error "Неизвестная опция: $1"
            echo "Используйте $0 --help для справки"
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
