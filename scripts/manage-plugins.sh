#!/bin/bash

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}!${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Конфигурация
# Автоматически определяем IP хоста для WSL2 совместимости
if command -v ip &> /dev/null; then
    # Получаем IP хоста Windows из WSL2
    HOST_IP=$(ip route show default | awk '/default/ {print $3}' | head -1)
    if [ -z "$HOST_IP" ]; then
        HOST_IP="localhost"
    fi
else
    HOST_IP="localhost"
fi

ARTIFACTORY_HOST="$HOST_IP"
ARTIFACTORY_PORT="30002"
DOCKER_REGISTRY_PORT="30502"
NAMESPACE="minecraft"

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    УПРАВЛЕНИЕ ПЛАГИНАМИ"
    echo "================================================================================"
    echo ""
    echo "ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 {publish|economy-api|full}"
    echo ""
    echo "КОМАНДЫ:"
    echo "  publish     - Опубликовать все плагины и JAR в Artifactory"
    echo "  economy-api - Обновить только economy-api (JAR + Docker образ)"
    echo "  full        - Полный цикл (сборка + публикация + обновление образа)"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0 publish     # Публикация всех плагинов"
    echo "  $0 economy-api # Обновление economy-api"
    echo "  $0 full        # Полный цикл"
    echo ""
    echo "================================================================================"
}

check_artifactory() {
    log_info "Проверка доступности Artifactory..."
    if curl -s "http://$ARTIFACTORY_HOST:$ARTIFACTORY_PORT/" >/dev/null; then
        log_success "Artifactory доступен"
    else
        log_error "Artifactory недоступен на http://$ARTIFACTORY_HOST:$ARTIFACTORY_PORT"
        exit 1
    fi
}

check_docker_registry() {
    log_info "Проверка доступности Docker Registry..."
    if curl -s "http://localhost:$DOCKER_REGISTRY_PORT/v2/" >/dev/null; then
        log_success "Docker Registry доступен"
    else
        log_error "Docker Registry недоступен на http://localhost:$DOCKER_REGISTRY_PORT"
        exit 1
    fi
}

build_gr_plugins() {
    log_info "Сборка GR плагинов..."
    
    # gr-core-plugin
    log_info "Сборка gr-core-plugin..."
    cd ../gr-core-plugin
    if [ -f "gradlew" ]; then
        ./gradlew clean build
        log_success "gr-core-plugin собран"
    else
        log_error "Gradle wrapper не найден в gr-core-plugin"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-player-plugin
    log_info "Сборка gr-player-plugin..."
    cd ../gr-player-plugin
    if [ -f "gradlew" ]; then
        ./gradlew clean build
        log_success "gr-player-plugin собран"
    else
        log_error "Gradle wrapper не найден в gr-player-plugin"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-race-plugin
    log_info "Сборка gr-race-plugin..."
    cd ../gr-race-plugin
    if [ -f "gradlew" ]; then
        ./gradlew clean build
        log_success "gr-race-plugin собран"
    else
        log_error "Gradle wrapper не найден в gr-race-plugin"
        exit 1
    fi
    cd - >/dev/null
    
    log_success "Все GR плагины собраны"
}

publish_gr_plugins() {
    log_info "Публикация GR плагинов в Artifactory..."
    
    # gr-core-plugin
    log_info "Публикация gr-core-plugin..."
    cd ../gr-core-plugin
    local jar_file="build/libs/gr-core-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-core-plugin/1.0.0
        local POD
        POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-core-plugin/1.0.0/gr-core-plugin-1.0.0.jar"
        log_success "gr-core-plugin опубликован"
    else
        log_error "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-player-plugin
    log_info "Публикация gr-player-plugin..."
    cd ../gr-player-plugin
    jar_file="build/libs/gr-player-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-player-plugin/1.0.0
        local POD
        POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-player-plugin/1.0.0/gr-player-plugin-1.0.0.jar"
        log_success "gr-player-plugin опубликован"
    else
        log_error "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-race-plugin
    log_info "Публикация gr-race-plugin..."
    cd ../gr-race-plugin
    jar_file="build/libs/gr-race-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-race-plugin/1.0.0
        local POD
        POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-race-plugin/1.0.0/gr-race-plugin-1.0.0.jar"
        log_success "gr-race-plugin опубликован"
    else
        log_error "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    log_success "Все GR плагины опубликованы"
}

publish_plugin() {
    log_info "Публикация плагина в Artifactory..."
    cd plugin/purpur-plugin
    if [ -f "gradlew" ]; then
        log_info "Публикуем в Artifactory по адресу http://$ARTIFACTORY_HOST:$ARTIFACTORY_PORT"
        ./gradlew clean build
        local jar_file="build/libs/purpur-plugin-1.0.0.jar"
        if [ -f "$jar_file" ]; then
            kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0
            kubectl cp "$jar_file" minecraft/$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}'):/usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0/purpur-plugin-1.0.0.jar
            log_success "Плагин загружен в Artifactory"
        else
            log_error "JAR файл не найден: $jar_file"
            exit 1
        fi
    else
        log_error "Gradle wrapper не найден"
        exit 1
    fi
    cd - > /dev/null
}

publish_economy_api() {
    log_info "Публикация economy-api в Artifactory..."
    cd services/economy-api
    if [ -f "gradlew" ]; then
        log_info "Публикуем в Artifactory по адресу http://$ARTIFACTORY_HOST:$ARTIFACTORY_PORT"
        ./gradlew clean build
        local jar_file="build/libs/economy-api-1.0.0.jar"
        if [ -f "$jar_file" ]; then
            kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0
            kubectl cp "$jar_file" minecraft/$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}'):/usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0/economy-api-1.0.0.jar
            log_success "economy-api загружен в Artifactory"
        else
            log_error "JAR файл не найден: $jar_file"
            exit 1
        fi
    else
        log_error "Gradle wrapper не найден"
        exit 1
    fi
    cd - > /dev/null
}

update_economy_api_image() {
    log_info "Обновление образа economy-api..."
    local tag="1.0.0-$(date +%Y%m%d%H%M%S)"
    local artifact_url="http://host.docker.internal:$ARTIFACTORY_PORT/economy-api/com/example/economy-api/1.0.0/economy-api-1.0.0.jar"
    
    docker build -f services/economy-api/Dockerfile \
        --build-arg ARTIFACT_URL="$artifact_url" \
        -t "localhost:$DOCKER_REGISTRY_PORT/economy-api:$tag" \
        services/economy-api
    
    docker push "localhost:$DOCKER_REGISTRY_PORT/economy-api:$tag"
    
    log_info "Обновление deployment economy-api..."
    kubectl -n "$NAMESPACE" set image deploy/economy-api "economy-api=localhost:$DOCKER_REGISTRY_PORT/economy-api:$tag"
    kubectl -n "$NAMESPACE" rollout status deploy/economy-api --timeout=300s
    
    log_success "Образ economy-api обновлен: $tag"
}

main() {
    case "${1:-}" in
        "publish")
            check_artifactory
            check_docker_registry
            build_gr_plugins
            publish_gr_plugins
            publish_plugin
            publish_economy_api
            log_success "Все артефакты опубликованы"
            ;;
        "economy-api")
            check_artifactory
            check_docker_registry
            publish_economy_api
            update_economy_api_image
            log_success "economy-api обновлен"
            ;;
        "full")
            check_artifactory
            check_docker_registry
            build_gr_plugins
            publish_gr_plugins
            publish_plugin
            publish_economy_api
            update_economy_api_image
            log_success "Полный цикл завершен"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Использование: $0 {publish|economy-api|full|help}"
            echo "  publish     - Опубликовать все плагины и JAR"
            echo "  economy-api - Обновить только economy-api"
            echo "  full        - Полный цикл (сборка + публикация + обновление образа)"
            echo "  help        - Показать справку"
            exit 1
            ;;
    esac
}

main "$@"
