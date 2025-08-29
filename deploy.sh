#!/bin/bash

# ================================================================================
#                    СКРИПТ РАЗВЕРТЫВАНИЯ ИНФРАСТРУКТУРЫ MINECRAFT
# ================================================================================
# 
# Описание: Полностью автоматизированное развертывание Minecraft сервера
#          с Velocity, Purpur, PostgreSQL, Redis и Economy API
# 
# Архитектура: NodePort для стабильного доступа в OrbStack
#              Порт 30000 для Velocity (фиксированный)
# 
# Автор: AI Assistant
# Версия: 2.0.0
# ================================================================================

set -e

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
NAMESPACE="minecraft"
REGISTRY="localhost:30500"

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

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    СКРИПТ РАЗВЕРТЫВАНИЯ MINECRAFT ИНФРАСТРУКТУРЫ"
    echo "================================================================================"
    echo ""
    echo "ОПИСАНИЕ:"
    echo "  Полностью автоматизированное развертывание Minecraft сервера с нуля"
    echo "  Включает Velocity (прокси), Purpur (лобби), PostgreSQL, Redis и Economy API"
    echo ""
    echo "ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 [опции]"
    echo ""
    echo "ОПЦИИ:"
    echo "  --help, -h     Показать эту справку"
    echo "  --cleanup      Полная очистка кластера и перезапуск"
    echo "  --force        Принудительное обновление всех компонентов"
    echo ""
    echo "ТРЕБОВАНИЯ:"
    echo "  - kubectl настроен и подключен к кластеру"
    echo "  - Helm 3.x установлен"
    echo "  - Docker запущен"
    echo "  - OrbStack с Kubernetes"
    echo ""
    echo "КОМПОНЕНТЫ:"
    echo "  - PostgreSQL: База данных для экономики"
    echo "  - Redis: Кэширование и события"
    echo "  - Local Registry: Docker registry для образов"
    echo "  - Velocity: Minecraft прокси сервер"
    echo "  - Purpur: Minecraft лобби сервер"
    echo "  - Economy API: Микросервис экономики"
    echo ""
    echo "ПОРТЫ:"
    echo "  - Velocity: NodePort:30000 (внешний доступ)"
    echo "  - Purpur: 25565 (внутренний)"
    echo "  - Economy API: 8080 (внутренний)"
    echo "  - PostgreSQL: 5432 (внутренний)"
    echo "  - Redis: 6379 (внутренний)"
    echo ""
    echo "АРХИТЕКТУРА:"
    echo "  Использует NodePort для стабильного внешнего доступа"
    echo "  Фиксированный порт 30000 для Velocity"
    echo "  Автоматическое создание кошельков при входе игроков"
    echo "  Redis кэширование для производительности"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0                    # Обычное развертывание"
    echo "  $0 --cleanup          # Полная очистка и перезапуск"
    echo "  $0 --force            # Принудительное обновление"
    echo ""
    echo "================================================================================"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl не найден. Установите kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "Helm не найден. Установите Helm 3.x."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker не найден. Запустите Docker."
        exit 1
    fi
    
    success "Все зависимости проверены"
}

# Очистка кластера
cleanup() {
    echo ""
    echo "================================================================================"
    echo "                    ПОЛНАЯ ОЧИСТКА КЛАСТЕРА MINECRAFT"
    echo "================================================================================"
    echo ""
    
    log "Начинаю полную очистку кластера..."
    
    # Удаляем все ресурсы из namespace
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log "Удаляю namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        success "Namespace $NAMESPACE удален"
    fi
    
    # Ждем полного удаления
    log "Ожидаю завершения очистки..."
    sleep 5
    
    success "Кластер полностью очищен"
    echo ""
}

# Развертывание инфраструктуры
deploy() {
    echo ""
    echo "================================================================================"
    echo "                    РАЗВЕРТЫВАНИЕ MINECRAFT ИНФРАСТРУКТУРЫ"
    echo "================================================================================"
    echo ""
    
    log "Начинаю развертывание инфраструктуры..."
    
    # Создаем namespace
    log "Создаю namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    success "Namespace $NAMESPACE создан"
    
    # Развертываем PostgreSQL
    log "Развертываю PostgreSQL..."
    helm upgrade --install postgres ./helm/postgres \
        --namespace $NAMESPACE \
        --wait \
        --timeout 5m
    success "PostgreSQL развернут"
    
    # Развертываем Redis
    log "Развертываю Redis..."
    helm upgrade --install redis ./helm/redis \
        --namespace $NAMESPACE \
        --wait \
        --timeout 5m
    success "Redis развернут"
    
    # Развертываем локальный registry
    log "Развертываю локальный Docker registry..."
    helm upgrade --install registry ./helm/registry \
        --namespace $NAMESPACE \
        --wait \
        --timeout 5m
    success "Локальный registry развернут"
    
    # Ждем готовности registry
    log "Ожидаю готовности registry..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=registry -n $NAMESPACE --timeout=2m
    
    # Собираем и загружаем economy-api
    log "Собираю и загружаю economy-api..."
    ./deploy-economy-api.sh
    success "Economy API развернут"
    
    # Развертываем Velocity
    log "Развертываю Velocity..."
    helm upgrade --install velocity ./helm/velocity \
        --namespace $NAMESPACE \
        --wait \
        --timeout 5m
    success "Velocity развернут"
    
    # Развертываем Purpur
    log "Развертываю Purpur..."
    helm upgrade --install purpur-lobby ./helm/purpur \
        --namespace $NAMESPACE \
        --wait \
        --timeout 5m
    success "Purpur развернут"
    
    # Ждем готовности всех подов
    log "Ожидаю готовности всех сервисов..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velocity -n $NAMESPACE --timeout=2m
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=purpur-shard -n $NAMESPACE --timeout=2m
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=economy-api -n $NAMESPACE --timeout=2m
    
    success "Все сервисы готовы!"
    
    # Показываем информацию о подключении
    show_connection_info
}

# Показать информацию о подключении
show_connection_info() {
    echo ""
    echo "================================================================================"
    echo "                    MINECRAFT СЕРВЕР ГОТОВ К ПОДКЛЮЧЕНИЮ"
    echo "================================================================================"
    echo ""
    
    # Получаем NodePort для Velocity
    NODE_PORT=$(kubectl get svc velocity -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
    if [ -n "$NODE_PORT" ]; then
        echo "  АДРЕС СЕРВЕРА: localhost:$NODE_PORT"
        echo "  ТИП ПОДКЛЮЧЕНИЯ: NodePort Service (Стабильный)"
        echo "  СТАТУС: Готов"
        echo ""
        echo "  ОСОБЕННОСТИ:"
        echo "    - Не требует port-forward"
        echo "    - Фиксированный номер порта"
        echo "    - Автоматическое восстановление"
        echo "    - Нативная интеграция с Kubernetes"
    else
        echo "  СТАТУС: Предупреждение - NodePort не настроен"
        echo "  ДЕЙСТВИЕ: Проверьте статус сервиса: kubectl get svc velocity -n $NAMESPACE"
    fi
    
    echo ""
    echo "================================================================================"
    echo "  СЛЕДУЮЩИЕ ШАГИ:"
    echo "    1. Проверьте статус подов: kubectl get pods -n $NAMESPACE"
    echo "    2. Подключитесь к серверу: localhost:$NODE_PORT"
    echo "    3. Загрузите плагин: ./upload-plugin.sh"
    echo ""
    echo "  ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=velocity"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "    kubectl get svc velocity -n $NAMESPACE"
    echo "================================================================================"
    echo ""
}

# Главная функция
main() {
    # Парсим аргументы
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --cleanup)
                cleanup
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            *)
                error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Проверяем зависимости
    check_dependencies
    
    # Если указан cleanup, очищаем и развертываем заново
    if [[ "$*" == *"--cleanup"* ]]; then
        cleanup
        deploy
    else
        # Обычное развертывание
        deploy
    fi
    
    success "Развертывание завершено успешно!"
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
