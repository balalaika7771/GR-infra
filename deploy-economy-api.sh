#!/bin/bash

# Economy API Deployment Script
# Builds and deploys economy-api microservice from source code
# Usage: ./deploy-economy-api.sh [--force]

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

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Переменные
NAMESPACE="minecraft"
ECONOMY_API_DIR="services/economy-api"
REGISTRY_HOST="localhost:30500"
FORCE_DEPLOY=false

# Проверка аргументов
if [[ "$1" == "--force" ]]; then
    FORCE_DEPLOY=true
fi

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    # Проверяем Gradle (локальный wrapper или глобальный)
    if [ -f "./services/economy-api/gradlew" ]; then
        GRADLE_CMD="$(pwd)/services/economy-api/gradlew"
        log "Используется локальный Gradle wrapper: $GRADLE_CMD"
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

# Проверка Kubernetes кластера
check_kubernetes() {
    log "Проверяем Kubernetes кластер..."
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Не удается подключиться к Kubernetes кластеру"
        exit 1
    fi
    
    # Проверяем namespace
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        error "Namespace $NAMESPACE не найден. Сначала запустите ./deploy.sh"
        exit 1
    fi
    
    success "Kubernetes кластер доступен"
}

# Проверка registry
check_registry() {
    log "Проверяем Docker registry..."
    
    # Проверяем, доступен ли registry
    if ! curl -s http://$REGISTRY_HOST/v2/ &> /dev/null; then
        warning "Registry недоступен по адресу $REGISTRY_HOST"
        warning "Попробуем использовать локальный образ"
        REGISTRY_HOST=""
    else
        success "Registry доступен"
    fi
}

# Сборка economy-api
build_economy_api() {
    log "Собираем economy-api..."
    
    cd $ECONOMY_API_DIR
    
    # Очистка предыдущей сборки
    log "Очистка предыдущей сборки..."
    $GRADLE_CMD clean -q
    
    # Компиляция
    log "Компиляция..."
    $GRADLE_CMD compileJava -q
    
    # Сборка JAR
    log "Сборка JAR файла..."
    $GRADLE_CMD bootJar -q
    
    success "economy-api собран: build/libs/economy-api-1.0.0.jar"
    
    cd - > /dev/null
}

# Создание Docker образа
build_docker_image() {
    log "Создаем Docker образ..."
    
    local image_tag="economy-api:dev-$(date +%Y%m%d%H%M%S)"
    
    # Собираем образ
    docker build -t $image_tag $ECONOMY_API_DIR
    
    if [ -n "$REGISTRY_HOST" ]; then
        # Тегируем для registry
        local registry_image="$REGISTRY_HOST/$image_tag"
        docker tag $image_tag $registry_image
        
        # Пушим в registry
        log "Загружаем образ в registry..."
        if docker push $registry_image; then
            success "Образ загружен в registry: $registry_image"
            echo $registry_image > .economy-api-image
        else
            warning "Не удалось загрузить в registry, используем локальный образ"
            echo $image_tag > .economy-api-image
        fi
    else
        # Используем локальный образ
        echo $image_tag > .economy-api-image
    fi
    
    success "Docker образ создан"
}

# Обновление deployment в Kubernetes
update_kubernetes_deployment() {
    log "Обновляем deployment в Kubernetes..."
    
    local image_name=$(cat .economy-api-image)
    
    # Проверяем, существует ли deployment
    if ! kubectl get deployment economy-api -n $NAMESPACE &> /dev/null; then
        log "Deployment economy-api не найден, создаем новый..."
        
        # Создаем deployment через Helm с полным именем образа
        # Используем kubectl для создания deployment с правильным образом
        kubectl create deployment economy-api --image=$image_name -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
        
        # Создаем сервис
        kubectl expose deployment economy-api --port=8080 --target-port=8080 -n $NAMESPACE
        
        # Устанавливаем правильную политику загрузки образа
        if [ -n "$REGISTRY_HOST" ]; then
            kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'
        else
            kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Never"}]'
        fi
        
        success "Deployment economy-api создан"
    else
        log "Обновляем существующий deployment..."
        
        # Обновляем образ
        kubectl set image deployment/economy-api economy-api=$image_name -n $NAMESPACE
        
        # Устанавливаем правильную политику загрузки образа
        if [ -n "$REGISTRY_HOST" ]; then
            kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'
        else
            kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Never"}]'
        fi
        
        success "Deployment economy-api обновлен"
    fi
}

# Ожидание готовности
wait_for_ready() {
    log "Ожидаем готовности economy-api..."
    
    kubectl rollout status deployment/economy-api -n $NAMESPACE --timeout=300s
    
    success "economy-api готов"
}

# Проверка здоровья API
check_api_health() {
    log "Проверяем здоровье API..."
    
    # Ждем немного для стабилизации
    sleep 5
    
    # Проверяем readiness probe
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=economy-api --field-selector=status.phase=Running | grep -q "1/1"; then
        success "economy-api работает и готов к запросам"
    else
        warning "economy-api может быть не готов"
        log "Проверьте логи: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=economy-api"
    fi
}

# Очистка
cleanup() {
    log "Очистка временных файлов..."
    rm -f .economy-api-image
    success "Очистка завершена"
}

# Главная функция
main() {
    log "Начинаем обновление economy-api..."
    
    check_dependencies
    check_kubernetes
    check_registry
    build_economy_api
    build_docker_image
    update_kubernetes_deployment
    wait_for_ready
    check_api_health
    
    success "Обновление economy-api завершено успешно!"
    
}

# Обработка ошибок
trap 'error "Произошла ошибка. Проверьте логи выше."; cleanup; exit 1' ERR

# Запуск
main "$@"
cleanup
