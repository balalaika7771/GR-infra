#!/bin/bash

# ================================================================================
#                    СКРИПТ РАЗРАБОТКИ ECONOMY API
# ================================================================================
# 
# Описание: Интерактивный скрипт для разработки микросервиса экономики
#          с автоматической пересборкой, мониторингом и горячей заменой
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
SERVICE_NAME="economy-api"
SERVICE_DIR="services/economy-api"
WATCH_DIR="$SERVICE_DIR/src"

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
    echo "                    СКРИПТ РАЗРАБОТКИ ECONOMY API"
    echo "================================================================================"
    echo ""
    echo "ОПИСАНИЕ:"
    echo "  Интерактивный скрипт для разработки микросервиса экономики"
    echo "  Включает автоматическую пересборку, мониторинг и горячую замену"
    echo ""
    echo "ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 [опции]"
    echo ""
    echo "ОПЦИИ:"
    echo "  --help, -h     Показать эту справку"
    echo "  --watch        Автоматическая пересборка при изменениях"
    echo "  --deploy       Быстрая сборка и развертывание"
    echo "  --logs         Просмотр логов в реальном времени"
    echo "  --health       Проверка здоровья сервиса"
    echo "  --restart      Перезапуск сервиса"
    echo "  --clean        Очистка и пересборка"
    echo ""
    echo "РЕЖИМЫ РАБОТЫ:"
    echo "  --watch        Автоматический режим разработки"
    echo "  --deploy       Одноразовая сборка и развертывание"
    echo "  --logs         Мониторинг логов"
    echo "  --health       Диагностика сервиса"
    echo ""
    echo "ТРЕБОВАНИЯ:"
    echo "  - Gradle 8.5+ установлен или gradlew доступен"
    echo "  - Docker запущен"
    echo "  - Kubernetes кластер доступен"
    echo "  - Namespace $NAMESPACE создан"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0 --watch     # Автоматическая разработка"
    echo "  $0 --deploy    # Быстрое развертывание"
    echo "  $0 --logs      # Просмотр логов"
    echo "  $0 --health    # Проверка здоровья"
    echo ""
    echo "================================================================================"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    # Проверяем Gradle (локальный wrapper или глобальный)
    if [ -f "$SERVICE_DIR/gradlew" ]; then
        GRADLE_CMD="$SERVICE_DIR/gradlew"
        log "Используется локальный Gradle wrapper"
    elif command -v gradle &> /dev/null; then
        GRADLE_CMD="gradle"
        log "Используется глобальный Gradle"
    else
        error "Gradle не найден. Установите Gradle 8.5+ или используйте gradlew."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker не найден. Запустите Docker."
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        error "Namespace $NAMESPACE не найден. Запустите deploy.sh сначала."
        exit 1
    fi
    
    success "Все зависимости проверены"
}

# Быстрая сборка и развертывание
quick_deploy() {
    log "Быстрая сборка и развертывание..."
    
    # Сборка
    cd $SERVICE_DIR
    $GRADLE_CMD clean bootJar -x test -q
    cd ../..
    
    # Создание образа
    JAR_FILE=$(find $SERVICE_DIR/build/libs -name "economy-api-*.jar" | head -1)
    
    cat > /tmp/Dockerfile.quick << EOF
FROM openjdk:21-jdk-slim
WORKDIR /app
COPY $JAR_FILE app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
EOF
    
    docker build -f /tmp/Dockerfile.quick -t $REGISTRY/$SERVICE_NAME:dev .
    rm /tmp/Dockerfile.quick
    
    # Загрузка в registry
    docker push $REGISTRY/$SERVICE_NAME:dev
    
    # Обновление deployment
    kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$REGISTRY/$SERVICE_NAME:dev -n $NAMESPACE
    
    success "Быстрое развертывание завершено"
}

# Автоматический режим разработки
watch_mode() {
    log "Запуск автоматического режима разработки..."
    echo ""
    echo "================================================================================"
    echo "                    РЕЖИМ АВТОМАТИЧЕСКОЙ РАЗРАБОТКИ"
    echo "================================================================================"
    echo ""
    echo "  СТАТУС: Отслеживание изменений в $WATCH_DIR"
    echo "  ДЕЙСТВИЯ:"
    echo "    - Автоматическая пересборка при изменениях"
    echo "    - Быстрое развертывание в Kubernetes"
    echo "    - Мониторинг логов и здоровья"
    echo ""
    echo "  УПРАВЛЕНИЕ:"
    echo "    Ctrl+C - Остановка режима"
    echo "    Enter - Принудительная пересборка"
    echo ""
    echo "================================================================================"
    echo ""
    
    # Проверяем наличие inotify-tools
    if ! command -v inotifywait &> /dev/null; then
        warning "inotify-tools не установлен. Используем простой polling режим."
        watch_simple
    else
        watch_inotify
    fi
}

# Простой режим отслеживания
watch_simple() {
    log "Запуск простого режима отслеживания (polling каждые 5 секунд)..."
    
    while true; do
        if [ -f "$WATCH_DIR/.trigger" ]; then
            log "Обнаружены изменения, запуск пересборки..."
            rm -f "$WATCH_DIR/.trigger"
            quick_deploy
            show_status
        fi
        
        sleep 5
    done
}

# Режим отслеживания с inotify
watch_inotify() {
    log "Запуск inotify режима отслеживания..."
    
    # Создаем временный файл для триггера
    touch "$WATCH_DIR/.trigger"
    
    # Запускаем inotify в фоне
    inotifywait -m -r -e modify,create,delete "$WATCH_DIR" --format '%w%f' | while read file; do
        if [[ "$file" != *".trigger" ]]; then
            log "Обнаружены изменения в: $file"
            touch "$WATCH_DIR/.trigger"
        fi
    done &
    
    INOTIFY_PID=$!
    
    # Основной цикл
    while true; do
        if [ -f "$WATCH_DIR/.trigger" ]; then
            log "Обнаружены изменения, запуск пересборки..."
            rm -f "$WATCH_DIR/.trigger"
            quick_deploy
            show_status
        fi
        
        sleep 2
    done
    
    # Очистка при выходе
    kill $INOTIFY_PID 2>/dev/null || true
}

# Просмотр логов
show_logs() {
    log "Запуск просмотра логов в реальном времени..."
    
    # Находим pod
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD_NAME" ]; then
        error "Pod $SERVICE_NAME не найден"
        return 1
    fi
    
    echo "================================================================================"
    echo "                    ЛОГИ ECONOMY API"
    echo "================================================================================"
    echo "  POD: $POD_NAME"
    echo "  NAMESPACE: $NAMESPACE"
    echo "  КОМАНДА: kubectl logs -f -n $NAMESPACE $POD_NAME"
    echo "================================================================================"
    echo ""
    
    kubectl logs -f -n $NAMESPACE $POD_NAME
}

# Проверка здоровья
check_health() {
    log "Проверка здоровья сервиса..."
    
    echo "================================================================================"
    echo "                    ПРОВЕРКА ЗДОРОВЬЯ ECONOMY API"
    echo "================================================================================"
    echo ""
    
    # Статус подов
    echo "СТАТУС ПОДОВ:"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME -o wide
    
    echo ""
    echo "СТАТУС DEPLOYMENT:"
    kubectl get deployment $SERVICE_NAME -n $NAMESPACE -o wide
    
    echo ""
    echo "СТАТУС СЕРВИСА:"
    kubectl get svc $SERVICE_NAME -n $NAMESPACE -o wide
    
    echo ""
    echo "ЛОГИ (последние 20 строк):"
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$POD_NAME" ]; then
        kubectl logs -n $NAMESPACE $POD_NAME --tail=20
    else
        echo "Pod не найден"
    fi
    
    echo ""
    echo "================================================================================"
}

# Перезапуск сервиса
restart_service() {
    log "Перезапуск сервиса..."
    
    # Находим pod
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD_NAME" ]; then
        error "Pod $SERVICE_NAME не найден"
        return 1
    fi
    
    # Удаляем pod для перезапуска
    kubectl delete pod $POD_NAME -n $NAMESPACE
    
    log "Ожидание запуска нового пода..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=$SERVICE_NAME -n $NAMESPACE --timeout=2m
    
    success "Сервис перезапущен"
}

# Показать статус
show_status() {
    echo ""
    echo "================================================================================"
    echo "                    СТАТУС РАЗВЕРТЫВАНИЯ"
    echo "================================================================================"
    echo ""
    
    # Проверяем статус
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME --field-selector=status.phase=Running | grep -q "1/1"; then
        success "Сервис работает и готов к запросам"
    else
        warning "Сервис может быть не готов"
    fi
    
    echo ""
    echo "  ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo "    $0 --logs      # Просмотр логов"
    echo "    $0 --health    # Проверка здоровья"
    echo "    $0 --restart   # Перезапуск сервиса"
    echo ""
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
            --watch)
                WATCH_MODE=true
                shift
                ;;
            --deploy)
                QUICK_DEPLOY=true
                shift
                ;;
            --logs)
                SHOW_LOGS=true
                shift
                ;;
            --health)
                CHECK_HEALTH=true
                shift
                ;;
            --restart)
                RESTART_SERVICE=true
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
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
    
    # Выполняем действия
    if [ "$QUICK_DEPLOY" = true ]; then
        quick_deploy
        show_status
    elif [ "$SHOW_LOGS" = true ]; then
        show_logs
    elif [ "$CHECK_HEALTH" = true ]; then
        check_health
    elif [ "$RESTART_SERVICE" = true ]; then
        restart_service
    elif [ "$WATCH_MODE" = true ]; then
        watch_mode
    else
        # Показываем справку если нет опций
        show_help
    fi
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
