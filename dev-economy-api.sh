#!/bin/bash

# Economy API Development Workflow Script
# Automatically rebuilds Docker image and restarts pod in Kubernetes
# Supports local development with hot reload capabilities

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
ECONOMY_API_DIR="services/economy-api"
ECONOMY_API_LABEL="app.kubernetes.io/name=economy-api"
IMAGE_NAME="economy-api"
# Динамический тег для кэш-бастинга и гарантированной подстановки нового образа
IMAGE_TAG="dev-$(date +%Y%m%d%H%M%S)"
REGISTRY="localhost:30500"  # Внутренний registry в Kubernetes (NodePort)
LOCAL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
FULL_IMAGE="$LOCAL_IMAGE"

# Проверка зависимостей
check_dependencies() {
    log "Проверяем зависимости..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl не установлен"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен"
        exit 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        error "Maven не установлен"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes кластер недоступен"
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        error "Namespace $NAMESPACE не найден. Сначала запустите deploy.sh"
        exit 1
    fi
    
    # Проверяем доступность Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon недоступен"
        exit 1
    fi
    
    success "Все зависимости проверены"
}

# Гарантируем, что деплоймент economy-api существует
ensure_deployment() {
    if kubectl -n "$NAMESPACE" get deploy economy-api >/dev/null 2>&1; then
        return 0
    fi
    log "Деплоймент economy-api не найден. Выполняю начальную установку через Helm..."
    local repo imageTag pullPolicy
    if curl -fsS "http://$REGISTRY/v2/_catalog" >/dev/null 2>&1; then
        repo="$REGISTRY/$IMAGE_NAME"
        pullPolicy="IfNotPresent"
    else
        repo="$IMAGE_NAME"
        pullPolicy="Never"
    fi
    helm upgrade --install economy-api ./helm/economy-api \
        -n "$NAMESPACE" \
        --set image.repository="$repo" \
        --set image.tag="$IMAGE_TAG" \
        --set image.pullPolicy="$pullPolicy" \
        --wait || {
        error "Не удалось установить Helm release economy-api"
        exit 1
    }
}

## Убрано: попытки поднимать локальный реестр. Используем NodePort, иначе фоллбек на локальный образ.

# Сборка economy-api
build_economy_api() {
    log "Сборка economy-api..."
    
    if [ ! -d "$ECONOMY_API_DIR" ]; then
        error "Директория economy-api не найдена: $ECONOMY_API_DIR"
        exit 1
    fi
    
    cd "$ECONOMY_API_DIR"
    
    log "Очистка предыдущей сборки..."
    mvn clean
    
    log "Компиляция..."
    mvn compile
    
    log "Сборка JAR файла..."
    mvn package -DskipTests
    
    if [ ! -f "target/economy-api-1.0.0.jar" ]; then
        error "JAR файл не создан: target/economy-api-1.0.0.jar"
        exit 1
    fi
    
    success "economy-api собран"
    cd - > /dev/null
}

# Сборка Docker образа
build_docker_image() {
    log "Сборка Docker образа..."
    
    cd "$ECONOMY_API_DIR"
    
    # Собираем локальный образ
    docker build -t "$LOCAL_IMAGE" .
    
    success "Docker образ собран: $LOCAL_IMAGE"
    cd - > /dev/null
}

# Загрузка образа в registry
push_image_to_registry() {
    log "Загрузка образа в registry..."
    local candidate="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    docker tag "$LOCAL_IMAGE" "$candidate" || true
    if docker push "$candidate"; then
        FULL_IMAGE="$candidate"
        success "Образ загружен: $FULL_IMAGE"
    else
        FULL_IMAGE="$LOCAL_IMAGE"
        warning "Registry недоступен. Используем локальный образ: $FULL_IMAGE"
    fi
}

# Получение информации о поде economy-api
get_economy_api_pod() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -l $ECONOMY_API_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        error "Под economy-api не найден в namespace $NAMESPACE"
        exit 1
    fi
    
    echo "$pod_name"
}

# Обновление образа в Kubernetes
update_image_in_kubernetes() {
    log "Обновление образа в Kubernetes..."
    ensure_deployment
    
    # Обновляем deployment с новым образом
    kubectl set image deployment/economy-api economy-api="$FULL_IMAGE" -n $NAMESPACE
    # Настраиваем imagePullPolicy в зависимости от источника образа
    if [[ "$FULL_IMAGE" == "$LOCAL_IMAGE" ]]; then
        kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[
          {"op":"add","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}
        ]' || true
    else
        kubectl patch deployment economy-api -n $NAMESPACE --type='json' -p='[
          {"op":"add","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}
        ]' || true
    fi
    
    # Ждем обновления
    kubectl rollout status deployment/economy-api -n $NAMESPACE --timeout=300s
    
    success "Deployment обновлен с новым образом"
}

# Перезапуск пода (принудительно)
restart_pod() {
    log "Принудительный перезапуск пода..."
    
    # Удаляем под для принудительного пересоздания
    local pod_name=$(get_economy_api_pod)
    kubectl delete pod "$pod_name" -n $NAMESPACE
    
    # Ждем запуска нового пода
    log "Ожидание запуска нового пода..."
    kubectl wait --for=condition=ready pod -l $ECONOMY_API_LABEL -n $NAMESPACE --timeout=300s
    
    success "Под перезапущен"
}

# Проверка готовности по Kubernetes Ready
check_api_health() {
    log "Проверка готовности economy-api (Kubernetes Ready)..."
    if kubectl wait --for=condition=ready pod -l $ECONOMY_API_LABEL -n $NAMESPACE --timeout=120s; then
        success "economy-api pod в состоянии Ready"
        return 0
    fi
    error "economy-api не перешел в Ready"
    return 1
}

# Мониторинг логов
monitor_logs() {
    local pod_name=$(get_economy_api_pod)
    
    log "Мониторинг логов economy-api (Ctrl+C для выхода)..."
    kubectl logs -f -n $NAMESPACE "$pod_name"
}

# Показать справку
show_help() {
    echo "Economy API Development Tool (Docker-based)"
    echo ""
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --help, -h           Показать эту справку"
    echo "  --build              Только собрать economy-api"
    echo "  --docker             Собрать Docker образ"
    echo "  --deploy             Собрать, создать образ и развернуть в Kubernetes"
    echo "  --restart            Перезапустить под economy-api"
    echo "  --health             Проверить здоровье API"
    echo "  --logs               Показать логи economy-api"
    echo "  --watch              Автоматический мониторинг и перезапуск"
    echo ""
    echo "Примеры:"
    echo "  $0 --build           Собрать economy-api"
    echo "  $0 --docker          Собрать Docker образ"
    echo "  $0 --deploy          Полный цикл: сборка -> образ -> деплой"
    echo "  $0 --watch           Автоматический режим разработки"
    echo ""
    echo "Режим разработки:"
    echo "  $0 --watch           Запускает автоматический мониторинг"
    echo "                       При изменении исходного кода автоматически"
    echo "                       пересобирает образ и перезапускает сервис"
    echo ""
    echo "Для локального доступа к API:"
    echo "  1. Запустите в отдельном терминале:"
    echo "     kubectl port-forward -n minecraft svc/economy-api 8080:8080"
    echo "  2. API будет доступен по адресу: http://localhost:8080"
    echo "  3. Проверьте здоровье: curl http://localhost:8080/actuator/health"
    echo ""
    echo "Скрипт автоматически обнаружит port-forward и будет использовать его для проверок."
}

# Автоматический режим разработки
watch_mode() {
    log "Запуск автоматического режима разработки..."
    log "Отслеживаем изменения в $ECONOMY_API_DIR"
    log "Нажмите Ctrl+C для выхода"
    
    # Создаем временный файл для отслеживания изменений
    local temp_file=$(mktemp)
    find "$ECONOMY_API_DIR/src" -type f -name "*.java" -exec stat -f "%m %N" {} \; > "$temp_file"
    
    while true; do
        sleep 2
        
        # Проверяем изменения
        local new_temp_file=$(mktemp)
        find "$ECONOMY_API_DIR/src" -type f -name "*.java" -exec stat -f "%m %N" {} \; > "$new_temp_file"
        
        if ! cmp -s "$temp_file" "$new_temp_file"; then
            log "Обнаружены изменения в исходном коде!"
            
            # Полный цикл сборки и деплоя
            build_economy_api
            build_docker_image
            push_image_to_registry
            update_image_in_kubernetes
            
            # Обновляем временный файл
            mv "$new_temp_file" "$temp_file"
            
            log "Готово! Сервис обновлен с новым образом."
        else
            rm "$new_temp_file"
        fi
    done
}

# Главная функция
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --build)
            check_dependencies
            build_economy_api
            ;;
        --docker)
            check_dependencies
            build_economy_api
            build_docker_image
            ;;
        --deploy)
            check_dependencies
            build_economy_api
            build_docker_image
            push_image_to_registry
            update_image_in_kubernetes
            check_api_health
            ;;
        --restart)
            check_dependencies
            restart_pod
            ;;
        --health)
            check_dependencies
            check_api_health
            ;;
        --logs)
            check_dependencies
            monitor_logs
            ;;
        --watch)
            check_dependencies
            watch_mode
            ;;
        "")
            show_help
            exit 1
            ;;
        *)
            error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
