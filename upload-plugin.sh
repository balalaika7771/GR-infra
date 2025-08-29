#!/bin/bash

# Minecraft Plugin Deployment Script
# Supports Kubernetes deployment with automatic plugin updates
# Builds and deploys plugin to Purpur server

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логировани
log_info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Конфигурация
NAMESPACE="minecraft"
PURPUR_LABEL="app.kubernetes.io/name=purpur-shard"
PLUGIN_NAME="purpur-plugin"
PLUGIN_JAR="purpur-plugin-1.0.0.jar"
PLUGIN_DIR="plugin/purpur-plugin"
TARGET_DIR="target"

# Проверка зависимостей
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        log_error "Maven is not installed"
        exit 1
    fi
    
    if ! command -v java &> /dev/null; then
        log_error "Java is not installed"
        exit 1
    fi
    
    # Проверяем версию Java
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt "17" ]; then
        log_error "Java 17+ required, current version: $JAVA_VERSION"
        exit 1
    fi
    
    log_success "All dependencies verified"
}

# Проверка Kubernetes кластера
check_kubernetes() {
    log_info "Проверяем Kubernetes кластер..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes кластер недоступен"
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace $NAMESPACE не найден. Сначала запустите deploy.sh"
        exit 1
    fi
    
    log_success "Kubernetes кластер доступен"
}

# Сборка плагина
build_plugin() {
    log_info "Собираем плагин..."
    
    if [ ! -d "$PLUGIN_DIR" ]; then
        log_error "Директория плагина не найдена: $PLUGIN_DIR"
        exit 1
    fi
    
    cd "$PLUGIN_DIR"
    
    log_info "Очистка предыдущей сборки..."
    mvn clean
    
    log_info "Компиляция плагина..."
    mvn compile
    
    log_info "Сборка JAR файла..."
    mvn package -DskipTests
    
    if [ ! -f "$TARGET_DIR/$PLUGIN_JAR" ]; then
        log_error "JAR файл не создан: $TARGET_DIR/$PLUGIN_JAR"
        exit 1
    fi
    
    log_success "Плагин собран: $TARGET_DIR/$PLUGIN_JAR"
    cd - > /dev/null
}

# Получение информации о поде Purpur
get_purpur_pod() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -l $PURPUR_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_error "Под Purpur не найден в namespace $NAMESPACE"
        exit 1
    fi
    
    echo "$pod_name"
}

# Загрузка плагина в под
upload_plugin() {
    local pod_name="$1"
    
    log_info "Загружаем плагин в под $pod_name..."
    
    # Копируем JAR файл в под
    kubectl cp "$PLUGIN_DIR/$TARGET_DIR/$PLUGIN_JAR" "$NAMESPACE/$pod_name:/data/plugins/" || {
        log_error "Не удалось скопировать плагин в под"
        exit 1
    }
    
    log_success "Плагин скопирован в под"
}

# Перезапуск пода
restart_pod() {
    local pod_name="$1"
    
    log_info "Перезапускаем под $pod_name..."
    
    # Удаляем старый под
    kubectl delete pod "$pod_name" -n $NAMESPACE
    
    # Ждем запуска нового пода
    log_info "Ожидаем запуска нового пода..."
    kubectl wait --for=condition=ready pod -l $PURPUR_LABEL -n $NAMESPACE --timeout=300s
    
    log_success "Под перезапущен"
}

# Проверка работы плагина
verify_plugin() {
    log_info "Проверяем работу плагина..."
    
    # Ждем немного для загрузки плагина
    sleep 10
    
    # Получаем новый под
    local new_pod=$(get_purpur_pod)
    
    # Проверяем логи на наличие сообщения о загрузке плагина
    local plugin_loaded=$(kubectl logs "$new_pod" -n $NAMESPACE --tail=50 | grep -i "plugin enabled successfully" || true)
    
    if [ -n "$plugin_loaded" ]; then
        log_success "Плагин успешно загружен и работает!"
    else
        log_warning "Плагин может быть не загружен. Проверьте логи:"
        echo "kubectl logs $new_pod -n $NAMESPACE"
    fi
}

# Очистка временных файлов
cleanup() {
    log_info "Очистка..."
    
    # Удаляем временные файлы если есть
    if [ -f "/tmp/plugin_upload.log" ]; then
        rm -f "/tmp/plugin_upload.log"
    fi
    
    log_success "Очистка завершена"
}

# Показать справку
show_help() {
    echo "Minecraft Plugin Upload Tool"
    echo ""
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --help, -h     Показать эту справку"
    echo "  --no-restart   Не перезапускать под после загрузки"
    echo "  --verify       Только проверить статус плагина"
    echo ""
    echo "Примеры:"
    echo "  $0              Собрать и загрузить плагин"
    echo "  $0 --no-restart Загрузить плагин без перезапуска"
    echo "  $0 --verify     Проверить статус плагина"
    echo ""
    echo "Требования:"
    echo "  - Kubernetes кластер с запущенным Purpur"
    echo "  - Maven для сборки плагина"
    echo "  - Java 17+ для компиляции"
    echo "  - kubectl настроен и подключен к кластеру"
    echo ""
    echo "Процесс:"
    echo "1. Сборка плагина с помощью Maven"
    echo "2. Копирование JAR в под Purpur"
    echo "3. Перезапуск пода для загрузки плагина"
    echo "4. Проверка успешной загрузки"
}

# Главная функция
main() {
    local no_restart=false
    local verify_only=false
    
    # Парсим аргументы
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --no-restart)
                no_restart=true
                shift
                ;;
            --verify)
                verify_only=true
                shift
                ;;
            *)
                log_error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$verify_only" = true ]; then
        check_kubernetes
        local pod_name=$(get_purpur_pod)
        verify_plugin
        exit 0
    fi
    
    log_info "Начинаем загрузку плагина..."
    
    # Проверяем зависимости
    check_dependencies
    
    # Проверяем Kubernetes
    check_kubernetes
    
    # Собираем плагин
    build_plugin
    
    # Получаем информацию о поде
    local pod_name=$(get_purpur_pod)
    
    # Загружаем плагин
    upload_plugin "$pod_name"
    
    # Перезапускаем под если нужно
    if [ "$no_restart" = false ]; then
        restart_pod "$pod_name"
    fi
    
    # Проверяем работу плагина
    verify_plugin
    
    # Очистка
    cleanup
    
    log_success "Плагин успешно загружен!"
    
    echo ""
    echo "Следующие шаги:"
    echo "1. Подключитесь к серверу Minecraft"
    echo "2. Используйте команды плагина: /balance, /transfer"
    echo "3. Проверьте логи: kubectl logs -n $NAMESPACE -l $PURPUR_LABEL"
    echo ""
    echo "Доступные команды плагина:"
    echo "  /balance - показать баланс"
    echo "  /transfer <игрок> <сумма> - перевести деньги"
    echo "  /auth - информация об аккаунте"
    echo "  /ping - показать ping"
    echo "  /nms - тест NMS функций"
}

# Запуск скрипта
main "$@"
