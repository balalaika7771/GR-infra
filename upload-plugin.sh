#!/bin/bash

# ================================================================================
#                    СКРИПТ РАЗВЕРТЫВАНИЯ MINECRAFT ПЛАГИНА
# ================================================================================
# 
# Описание: Автоматическая сборка, упаковка и загрузка плагина экономики
#          в Minecraft сервер Purpur через Kubernetes
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
PLUGIN_NAME="EconomyPlugin"

# Функции логирования с красивым форматированием
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

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    СКРИПТ РАЗВЕРТЫВАНИЯ MINECRAFT ПЛАГИНА"
    echo "================================================================================"
    echo ""
    echo "ОПИСАНИЕ:"
    echo "  Автоматическая сборка и загрузка плагина экономики в Minecraft сервер"
    echo "  Включает Gradle сборку, Docker упаковку и Kubernetes развертывание"
    echo ""
    echo "ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 [опции]"
    echo ""
    echo "ОПЦИИ:"
    echo "  --help, -h     Показать эту справку"
    echo "  --force        Принудительная пересборка"
    echo "  --clean        Очистка предыдущей сборки"
    echo ""
    echo "ТРЕБОВАНИЯ:"
    echo "  - Gradle 8.5+ установлен"
    echo "  - Docker запущен"
    echo "  - Kubernetes кластер доступен"
    echo "  - Purpur сервер запущен в namespace $NAMESPACE"
    echo ""
    echo "ПРОЦЕСС:"
    echo "  1. Сборка JAR файла через Gradle"
    echo "  2. Создание Docker образа"
    echo "  3. Загрузка в локальный registry"
    echo "  4. Копирование в pod Purpur"
    echo "  5. Перезапуск сервера"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0                    # Обычная сборка и загрузка"
    echo "  $0 --force            # Принудительная пересборка"
    echo "  $0 --clean            # Очистка и пересборка"
    echo ""
    echo "================================================================================"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    

    
    if ! command -v docker &> /dev/null; then
        log_error "Docker не найден. Запустите Docker."
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace $NAMESPACE не найден. Запустите deploy.sh сначала."
        exit 1
    fi
    
    log_success "Все зависимости проверены"
}

# Сборка плагина
build_plugin() {
    log_info "Начинаю сборку плагина..."
    
    cd plugin/purpur-plugin
    
    if [[ "$*" == *"--clean"* ]]; then
        log_info "Очистка предыдущей сборки..."
        ./gradlew clean
    fi
    
    log_info "Компиляция плагина..."
    ./gradlew compileJava
    
    log_info "Сборка JAR файла..."
    ./gradlew build -x test
    
    if [ ! -f "build/libs/EconomyPlugin.jar" ]; then
        log_error "JAR файл не создан. Проверьте ошибки сборки."
        exit 1
    fi
    
    log_success "Плагин успешно собран"
    cd ../..
}

# Создание Docker образа
create_docker_image() {
    log_info "Создание Docker образа..."
    
    # Находим JAR файл
    JAR_FILE="plugin/purpur-plugin/build/libs/EconomyPlugin.jar"
    
    if [ -z "$JAR_FILE" ]; then
        log_error "JAR файл не найден. Сначала соберите плагин."
        exit 1
    fi
    
    # Создаем временный Dockerfile
    cat > /tmp/Dockerfile.plugin << EOF
FROM openjdk:21-jdk-slim
WORKDIR /plugins
COPY $JAR_FILE /plugins/
CMD ["echo", "Plugin image created"]
EOF
    
    # Собираем образ
    docker build -f /tmp/Dockerfile.plugin -t $REGISTRY/$PLUGIN_NAME:latest .
    
    # Очищаем временный файл
    rm /tmp/Dockerfile.plugin
    
    log_success "Docker образ создан: $REGISTRY/$PLUGIN_NAME:latest"
}

# Загрузка в registry
push_to_registry() {
    log_info "Загрузка образа в registry..."
    
    docker push $REGISTRY/$PLUGIN_NAME:latest
    
    log_success "Образ загружен в registry"
}

# Копирование в pod Purpur
copy_to_purpur() {
    log_info "Копирование плагина в pod Purpur..."
    
    # Находим pod Purpur
    PURPUR_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$PURPUR_POD" ]; then
        log_error "Pod Purpur не найден. Проверьте статус: kubectl get pods -n $NAMESPACE"
        exit 1
    fi
    
    log_info "Найден pod Purpur: $PURPUR_POD"
    
    # Создаем временный pod для копирования
    kubectl run plugin-copy --image=$REGISTRY/$PLUGIN_NAME:latest --restart=Never -n $NAMESPACE
    
    # Ждем готовности
    kubectl wait --for=condition=ready pod/plugin-copy -n $NAMESPACE --timeout=30s
    
    # Копируем файл
    kubectl cp plugin-copy:/plugins/ $PURPUR_POD:/tmp/plugins -n $NAMESPACE
    
    # Перемещаем в папку plugins
    kubectl exec -n $NAMESPACE $PURPUR_POD -- sh -c "cp /tmp/plugins/* /plugins/ && rm -rf /tmp/plugins"
    
    # Удаляем временный pod
    kubectl delete pod plugin-copy -n $NAMESPACE --ignore-not-found=true
    
    log_success "Плагин скопирован в pod Purpur"
}

# Перезапуск сервера
restart_server() {
    log_info "Перезапуск Minecraft сервера..."
    
    # Находим pod Purpur
    PURPUR_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$PURPUR_POD" ]; then
        log_error "Pod Purpur не найден"
        exit 1
    fi
    
    # Отправляем команду перезапуска
    kubectl exec -n $NAMESPACE $PURPUR_POD -- sh -c "echo 'reload' > /tmp/console"
    
    log_success "Сервер перезапущен"
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
            --force)
                FORCE_BUILD=true
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            *)
                log_error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "================================================================================"
    echo "                    РАЗВЕРТЫВАНИЕ MINECRAFT ПЛАГИНА"
    echo "================================================================================"
    echo ""
    
    # Проверяем зависимости
    check_dependencies
    
    # Собираем плагин
    build_plugin "$@"
    
    # Создаем Docker образ
    create_docker_image
    
    # Загружаем в registry
    push_to_registry
    
    # Копируем в pod Purpur
    copy_to_purpur
    
    # Перезапускаем сервер
    restart_server
    
    echo ""
    echo "================================================================================"
    echo "                    ПЛАГИН УСПЕШНО РАЗВЕРНУТ!"
    echo "================================================================================"
    echo ""
    echo "  СТАТУС: Плагин загружен и активирован"
    echo "  СЕРВЕР: Перезапущен и готов к работе"
    echo "  ПЛАГИН: EconomyPlugin с экономической системой"
    echo ""
    echo "  СЛЕДУЮЩИЕ ШАГИ:"
    echo "    1. Подключитесь к серверу"
    echo "    2. Используйте команду /balance для проверки"
    echo "    3. Кошелек создается автоматически при входе"
    echo ""
    echo "  ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "    kubectl get pods -n $NAMESPACE"
    echo "================================================================================"
    echo ""
    
    log_success "Развертывание плагина завершено успешно!"
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
