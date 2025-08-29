#!/bin/bash

# ================================================================================
#                    СКРИПТ РАЗВЕРТЫВАНИЯ ECONOMY API
# ================================================================================
# 
# Описание: Автоматическое развертывание микросервиса экономики
#          в Kubernetes кластере с локальным Docker registry
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
    echo "                    СКРИПТ РАЗВЕРТЫВАНИЯ ECONOMY API"
    echo "================================================================================"
    echo ""
    echo "ОПИСАНИЕ:"
    echo "  Автоматическое развертывание микросервиса экономики в Kubernetes"
    echo "  Включает Gradle сборку, Docker упаковку и Kubernetes deployment"
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
    echo "  - Namespace $NAMESPACE создан"
    echo ""
    echo "ПРОЦЕСС:"
    echo "  1. Сборка JAR файла через Gradle"
    echo "  2. Создание Docker образа"
    echo "  3. Загрузка в локальный registry"
    echo "  4. Обновление Kubernetes deployment"
    echo "  5. Проверка готовности сервиса"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0                    # Обычная сборка и развертывание"
    echo "  $0 --force            # Принудительная пересборка"
    echo "  $0 --clean            # Очистка и пересборка"
    echo ""
    echo "================================================================================"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
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

# Сборка приложения
build_application() {
    log "Начинаю сборку приложения..."
    
    cd services/economy-api
    
    if [[ "$*" == *"--clean"* ]]; then
        log "Очистка предыдущей сборки..."
        ./gradlew clean
    fi
    
    log "Компиляция приложения..."
    ./gradlew compileJava
    
    log "Сборка JAR файла..."
    ./gradlew bootJar -x test
    
    if [ ! -f "build/libs/economy-api.jar" ]; then
        error "JAR файл не создан. Проверьте ошибки сборки."
        exit 1
    fi
    
    success "Приложение успешно собрано"
    cd ../..
}

# Создание Docker образа
create_docker_image() {
    log "Создание Docker образа..."
    
    # Находим JAR файл
    JAR_FILE="services/economy-api/build/libs/economy-api.jar"
    
    if [ -z "$JAR_FILE" ]; then
        error "JAR файл не найден. Сначала соберите приложение."
        exit 1
    fi
    
    # Создаем временный Dockerfile
    cat > /tmp/Dockerfile.economy << EOF
FROM openjdk:21-jdk-slim
WORKDIR /app
COPY $JAR_FILE app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
EOF
    
    # Собираем образ
    docker build -f /tmp/Dockerfile.economy -t $REGISTRY/$SERVICE_NAME:latest .
    
    # Очищаем временный файл
    rm /tmp/Dockerfile.economy
    
    success "Docker образ создан: $REGISTRY/$SERVICE_NAME:latest"
}

# Загрузка в registry
push_to_registry() {
    log "Загрузка образа в registry..."
    
    docker push $REGISTRY/$SERVICE_NAME:latest
    
    success "Образ загружен в registry"
}

# Обновление Kubernetes deployment
update_kubernetes() {
    log "Обновление Kubernetes deployment..."
    
    # Обновляем образ в deployment
    kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$REGISTRY/$SERVICE_NAME:latest -n $NAMESPACE
    
    success "Deployment обновлен с новым образом"
    
    # Ждем завершения rollout
    log "Ожидаю завершения rollout..."
    kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE --timeout=5m
    
    success "Rollout завершен успешно"
}

# Проверка готовности сервиса
check_service_health() {
    log "Проверка готовности сервиса..."
    
    # Ждем готовности пода
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=$SERVICE_NAME -n $NAMESPACE --timeout=2m
    
    # Проверяем health endpoint
    local retries=0
    while [ $retries -lt 10 ]; do
        if kubectl exec -n $NAMESPACE deployment/$SERVICE_NAME -- curl -f http://localhost:8080/actuator/health &>/dev/null; then
            success "Сервис готов и отвечает на запросы"
            return 0
        fi
        
        log "Сервис еще не готов, ожидаю... (попытка $((retries+1))/10)"
        sleep 5
        retries=$((retries+1))
    done
    
    warning "Сервис может быть не готов. Проверьте логи:"
    echo "kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME"
    return 1
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
                error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "================================================================================"
    echo "                    РАЗВЕРТЫВАНИЕ ECONOMY API"
    echo "================================================================================"
    echo ""
    
    # Проверяем зависимости
    check_dependencies
    
    # Собираем приложение
    build_application "$@"
    
    # Создаем Docker образ
    create_docker_image
    
    # Загружаем в registry
    push_to_registry
    
    # Обновляем Kubernetes
    update_kubernetes
    
    # Проверяем готовность
    check_service_health
    
    echo ""
    echo "================================================================================"
    echo "                    ECONOMY API УСПЕШНО РАЗВЕРНУТ!"
    echo "================================================================================"
    echo ""
    echo "  СТАТУС: Сервис запущен и готов к работе"
    echo "  ENDPOINTS:"
    echo "    - /api/economy/ensure-wallet/{userId} - Создание кошелька"
    echo "    - /api/economy/balance/{userId} - Получение баланса"
    echo "    - /actuator/health - Проверка здоровья"
    echo ""
    echo "  СЛЕДУЮЩИЕ ШАГИ:"
    echo "    1. Проверьте статус: kubectl get pods -n $NAMESPACE"
    echo "    2. Проверьте логи: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=$SERVICE_NAME"
    echo "    3. Протестируйте API endpoints"
    echo ""
    echo "  ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo "    kubectl get svc $SERVICE_NAME -n $NAMESPACE"
    echo "    kubectl describe deployment $SERVICE_NAME -n $NAMESPACE"
    echo "================================================================================"
    echo ""
    
    success "Развертывание Economy API завершено успешно!"
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
