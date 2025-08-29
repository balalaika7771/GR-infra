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

    helm uninstall purpur-lobby -n $NAMESPACE 2>/dev/null || true
    helm uninstall velocity -n $NAMESPACE 2>/dev/null || true
    helm uninstall redis -n $NAMESPACE 2>/dev/null || true
    helm uninstall postgres -n $NAMESPACE 2>/dev/null || true
    
    # Останавливаем port-forward если он запущен
    if [ -f .port-forward.pid ]; then
        PORT_FORWARD_PID=$(cat .port-forward.pid)
        kill $PORT_FORWARD_PID 2>/dev/null || true
        rm -f .port-forward.pid
        log "Port-forward остановлен"
    fi
    
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
    
    # Устанавливаем Helm chart: registry
    log "Устанавливаем Helm chart: registry"
    helm upgrade --install registry ./helm/registry -n "$NAMESPACE" --wait --timeout=180s
    success "Registry развернут"
    
    # Развертываем PostgreSQL
    log "Развертывание PostgreSQL..."
    helm upgrade --install postgres $HELM_DIR/postgres \
        --namespace $NAMESPACE \
        --set persistence.storageClass=local-path \
        --wait --timeout=600s
    success "PostgreSQL развернут"
    
    # Развертываем Redis
    log "Развертывание Redis..."
    helm upgrade --install redis $HELM_DIR/redis \
        --namespace $NAMESPACE \
        --wait
    success "Redis развернут"
    
    # Ждем готовности баз данных
    log "Ожидание готовности PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n $NAMESPACE --timeout=600s
    
    # Дополнительная проверка готовности PostgreSQL
    log "Проверка подключения к PostgreSQL..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if kubectl exec -n $NAMESPACE deployment/postgres -- pg_isready -U minecraft -d minecraft &>/dev/null; then
            success "PostgreSQL готов к работе"
            break
        fi
        log "PostgreSQL еще не готов, ждем... (попытка $((retries+1))/30)"
        sleep 10
        retries=$((retries+1))
    done
    
    if [ $retries -eq 30 ]; then
        error "PostgreSQL не стал готов за отведенное время"
        exit 1
    fi
    
    # Создаем базы данных (они уже созданы через initScripts в Helm чарте)
    log "Проверка баз данных auth_bridge и economy_api..."
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "\\l" | grep -E "(auth_bridge|economy_api)" || {
        warning "Базы данных не найдены, создаем их..."
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE auth_bridge;" 2>/dev/null || true
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE economy_api;" 2>/dev/null || true
    }
    success "Базы данных готовы"
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n $NAMESPACE --timeout=300s
    success "Redis готов"
    
    # Развертываем Velocity
    log "Развертывание Velocity прокси..."
    helm upgrade --install velocity $HELM_DIR/velocity \
        --namespace $NAMESPACE \
        --wait
    success "Velocity развернут"
    
    # Получаем информацию о внешнем доступе
    log "Настройка внешнего доступа к Velocity..."
    EXTERNAL_SERVICE="velocity-external"
    
    # Проверяем, что внешний сервис создался
    if kubectl get svc $EXTERNAL_SERVICE -n $NAMESPACE &>/dev/null; then
        success "Внешний сервис $EXTERNAL_SERVICE создан"
        
        # Получаем IP узла для доступа
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        if [ -n "$NODE_IP" ]; then
            success "Velocity доступен по стабильному адресу:"
            success "  - $NODE_IP:30000 (фиксированный NodePort)"
            success "  - localhost:30000 (если подключаетесь с того же узла)"
        else
            warning "Не удалось получить IP узла"
        fi
    else
        warning "Внешний сервис не создался, используйте основной сервис"
    fi
    
    # Развертываем Purpur
    log "Развертывание Purpur шарда..."
    helm upgrade --install purpur-lobby $HELM_DIR/purpur-shard \
        --namespace $NAMESPACE \
        --set persistence.storageClass=local-path \
        --wait --timeout=600s
    success "Purpur развернут"
    
    # Ждем готовности сервисов
    log "Ожидание готовности сервисов..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velocity -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=purpur-shard -n $NAMESPACE --timeout=300s
    success "Сервисы готовы"
    
    # Проверяем и перезапускаем port-forward если нужно
    log "Проверка и настройка port-forward..."
    if [ -f .port-forward.pid ]; then
        PORT_FORWARD_PID=$(cat .port-forward.pid)
        if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
            log "Port-forward завершился, перезапускаем..."
            rm -f .port-forward.pid
        fi
    fi
    
    if [ ! -f .port-forward.pid ]; then
        log "Запуск port-forward для локального доступа..."
        kubectl port-forward -n $NAMESPACE svc/velocity 25565:25565 > /dev/null 2>&1 &
        PORT_FORWARD_PID=$!
        echo $PORT_FORWARD_PID > .port-forward.pid
        sleep 3
        success "Port-forward запущен (PID: $PORT_FORWARD_PID)"
    fi
    
    # Первичная установка плагина в Purpur
    log "Устанавливаем Minecraft плагин (первичный деплой)..."
    if ./upload-plugin.sh; then
        success "Плагин установлен"
    else
        error "Не удалось установить плагин. Проверьте логи и повторите."
        exit 1
    fi
    
    # Развертываем economy-api через отдельный скрипт
    log "Развертывание economy-api..."
    if ./deploy-economy-api.sh; then
        success "economy-api развернут"
    else
        warning "Не удалось развернуть economy-api. Запустите ./deploy-economy-api.sh вручную."
    fi
    
    success "Развертывание завершено успешно!"
    
    # Получаем информацию о подключении
    echo ""
    echo "🎮 Minecraft сервер готов к подключению!"
    echo ""
    if [ -n "$NODE_IP" ]; then
        echo "Подключение к серверу:"
        echo "  $NODE_IP:30000 (фиксированный NodePort - стабильный доступ)"
        echo "  localhost:30000 (если подключаетесь с того же узла)"
        echo ""
        echo "✅ Автоматический доступ без port-forward!"
        echo "   Сервер доступен сразу после deploy"
        echo "   Порт 30000 всегда одинаковый!"
    else
        echo "⚠️  Не удалось получить IP узла"
        echo "Проверьте сервисы: kubectl get svc -n $NAMESPACE"
    fi
    echo ""
    echo "Следующие шаги:"
    echo "1. Проверьте статус подов: kubectl get pods -n $NAMESPACE"
    echo "2. Подключитесь к серверу: localhost:25565"
    echo "3. Для загрузки плагина используйте: ./upload-plugin.sh"
    echo ""
    echo "Полезные команды:"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=velocity"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "  kubectl get svc velocity -n $NAMESPACE"
    echo "  kubectl get nodes -o wide"
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
            error "Неизвестная опция: $1"
            echo "Используйте $0 --help для справки"
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
