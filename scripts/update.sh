#!/bin/bash

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }

# Конфигурация
NAMESPACE="minecraft"
ARTIFACTORY_HOST="artifactory"
ARTIFACTORY_PORT="80"
DOCKER_REGISTRY="registry:5000"
ECONOMY_DOCKER_IMAGE_REPO="$DOCKER_REGISTRY/economy-api"
PURPUR_LABEL="app.kubernetes.io/name=purpur-shard"

PLUGIN_COORDS_GROUP="com/example"
PLUGIN_COORDS_ARTIFACT="purpur-plugin"
PLUGIN_COORDS_VERSION="1.0.0"

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    ОБНОВЛЕНИЕ ПЛАГИНОВ И СЕРВИСОВ"
    echo "================================================================================"
    echo ""
    echo "ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 [ОПЦИИ]"
    echo ""
    echo "ОПЦИИ:"
    echo "  --all              Обновить все плагины и economy-api"
    echo "  --economy-api      Обновить только economy-api"
    echo "  --purpur-plugin    Обновить только purpur-plugin"
    echo "  --gr-core          Обновить только gr-core-plugin"
    echo "  --gr-player        Обновить только gr-player-plugin"
    echo "  --gr-race          Обновить только gr-race-plugin"
    echo "  --restart-purpur   Перезапустить Purpur (применяет изменения плагинов)"
    echo "  --help             Показать эту справку"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0 --all                    # Полное обновление всего"
    echo "  $0 --gr-core               # Обновить только gr-core-plugin"
    echo "  $0 --purpur-plugin         # Обновить purpur-plugin"
    echo "  $0 --economy-api           # Обновить economy-api"
    echo ""
}

# Проверка зависимостей
check_deps() {
    log "Проверка зависимостей..."
    command -v kubectl >/dev/null 2>&1 || { err "kubectl не найден"; exit 1; }
    command -v docker >/dev/null 2>&1 || { err "docker не найден"; exit 1; }
    command -v gradle >/dev/null 2>&1 || { err "gradle не найден"; exit 1; }
    
    # Проверяем gradlew в каждом проекте (пути согласно реальной структуре)
    local projects=("plugin/purpur-plugin" "../gr-core-plugin" "../gr-player-plugin" "../gr-race-plugin" "services/economy-api")
    for project in "${projects[@]}"; do
        if [ ! -f "$project/gradlew" ]; then
            err "gradlew не найден в $project"
            exit 1
        fi
        chmod +x "$project/gradlew"
    done
    ok "Все зависимости найдены"
}

# Проверка кластера
ensure_cluster() {
    log "Проверка кластера..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        err "Не удается подключиться к кластеру"
        exit 1
    fi
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        err "Namespace $NAMESPACE не найден"
        exit 1
    fi
    ok "Кластер доступен"
}

# Сборка GR плагинов
build_gr_plugins() {
    log "Сборка GR плагинов..."
    cd ../gr-core-plugin; ./gradlew -q clean build; ok "gr-core-plugin собран"; cd - >/dev/null
    cd ../gr-player-plugin; ./gradlew -q clean build; ok "gr-player-plugin собран"; cd - >/dev/null
    cd ../gr-race-plugin; ./gradlew -q clean build; ok "gr-race-plugin собран"; cd - >/dev/null
    ok "Все GR плагины собраны"
}

# Публикация GR плагинов
publish_gr_plugins() {
    log "Публикация GR плагинов в Artifactory..."
    local POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
    
    # gr-core-plugin
    cd ../gr-core-plugin
    local jar_file="build/libs/gr-core-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-core-plugin/1.0.0
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-core-plugin/1.0.0/gr-core-plugin-1.0.0.jar"
        ok "gr-core-plugin опубликован"
    else
        err "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-player-plugin
    cd ../gr-player-plugin
    jar_file="build/libs/gr-player-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-player-plugin/1.0.0
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-player-plugin/1.0.0/gr-player-plugin-1.0.0.jar"
        ok "gr-player-plugin опубликован"
    else
        err "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    # gr-race-plugin
    cd ../gr-race-plugin
    jar_file="build/libs/gr-race-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-race-plugin/1.0.0
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/org/owleebr/gr-race-plugin/1.0.0/gr-race-plugin-1.0.0.jar"
        ok "gr-race-plugin опубликован"
    else
        err "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
    
    ok "Все GR плагины опубликованы"
}

# Сборка и публикация purpur-plugin
build_purpur_plugin() {
    log "Сборка purpur-plugin..."
    cd plugin/purpur-plugin
    ./gradlew -q clean build
    ok "purpur-plugin собран"
    cd - >/dev/null
}

publish_purpur_plugin() {
    log "Публикация purpur-plugin в Artifactory..."
    local POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
    
    cd plugin/purpur-plugin
    local jar_file="build/libs/purpur-plugin-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0/purpur-plugin-1.0.0.jar"
        ok "purpur-plugin опубликован"
    else
        err "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
}

# Сборка и публикация economy-api
build_economy_api() {
    log "Сборка economy-api..."
    cd services/economy-api
    ./gradlew -q clean build
    ok "economy-api собран"
    cd - >/dev/null
}

publish_economy_jar() {
    log "Публикация economy-api JAR в Artifactory..."
    local POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}')
    
    cd services/economy-api
    local jar_file="build/libs/economy-api-1.0.0.jar"
    if [ -f "$jar_file" ]; then
        kubectl exec -n "$NAMESPACE" deployment/artifactory -- mkdir -p /usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0
        kubectl cp "$jar_file" "$NAMESPACE/$POD:/usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0/economy-api-1.0.0.jar"
        ok "economy-api JAR опубликован"
    else
        err "JAR не найден: $jar_file"
        exit 1
    fi
    cd - >/dev/null
}

# Сборка и push Docker образа economy-api
build_push_economy_image() {
    log "Сборка и push Docker образа economy-api..."
    local TAG="1.0.0-$(date +%Y%m%d%H%M%S)"
    
    # Используем локальный JAR файл
    local economy_jar="services/economy-api/build/libs/economy-api-1.0.0.jar"
    if [ ! -f "$economy_jar" ]; then
        log_error "Economy API JAR not found: $economy_jar"
        log_info "Building economy-api first..."
        cd services/economy-api
        ./gradlew clean build
        cd ../..
    fi
    
    # Создаем временный Dockerfile который копирует JAR напрямую
    cat > services/economy-api/Dockerfile.local <<EOF
FROM openjdk:21-jdk-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Копируем JAR файл напрямую
COPY build/libs/economy-api-1.0.0.jar app.jar

# Проверяем что файл существует
RUN test -s app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
EOF
    
    cd services/economy-api
    docker build -f Dockerfile.local \
        -t "$ECONOMY_DOCKER_IMAGE_REPO:$TAG" .
    rm -f Dockerfile.local
    
    docker push "$ECONOMY_DOCKER_IMAGE_REPO:$TAG"
    
    # Сохраняем тег для обновления deployment
    echo "$TAG" > .economy-api-image-tag
    ok "Docker образ собран и отправлен: $TAG"
    cd - >/dev/null
}

# Обновление deployment economy-api
rollout_economy_api() {
    log "Обновление deployment economy-api..."
    if [ -f "services/economy-api/.economy-api-image-tag" ]; then
        local IMAGE_TAG=$(cat "services/economy-api/.economy-api-image-tag")
        log "Используем собранный образ: $ECONOMY_DOCKER_IMAGE_REPO:$IMAGE_TAG"
        
        kubectl set image deployment/economy-api -n "$NAMESPACE" \
            economy-api="$ECONOMY_DOCKER_IMAGE_REPO:$IMAGE_TAG"
        
        kubectl rollout status deployment/economy-api -n "$NAMESPACE" --timeout=300s
        ok "economy-api обновлен"
    else
        err "Тег образа не найден"
        exit 1
    fi
}

# Перезапуск Purpur (применяет изменения плагинов)
restart_purpur() {
    log "Перезапуск Purpur для применения новых плагинов..."
    kubectl rollout restart deployment/purpur-lobby-purpur-shard -n "$NAMESPACE"
    kubectl rollout status deployment/purpur-lobby-purpur-shard -n "$NAMESPACE" --timeout=300s
    ok "Purpur перезапущен с новыми плагинами"
}

# Основная функция
main() {
    case "${1:-}" in
        "--all")
            check_deps
            ensure_cluster
            build_gr_plugins
            publish_gr_plugins
            build_purpur_plugin
            publish_purpur_plugin
            build_economy_api
            publish_economy_jar
            build_push_economy_image
            rollout_economy_api
            restart_purpur
            ok "Готово: все плагины и economy-api обновлены"
            ;;
        "--economy-api")
            check_deps
            ensure_cluster
            build_economy_api
            publish_economy_jar
            build_push_economy_image
            rollout_economy_api
            ok "Готово: economy-api обновлен"
            ;;
        "--purpur-plugin")
            check_deps
            ensure_cluster
            build_purpur_plugin
            publish_purpur_plugin
            restart_purpur
            ok "Готово: purpur-plugin обновлен и Purpur перезапущен"
            ;;
        "--gr-core")
            check_deps
            ensure_cluster
            build_gr_plugins
            publish_gr_plugins
            restart_purpur
            ok "Готово: gr-core-plugin обновлен и Purpur перезапущен"
            ;;
        "--gr-player")
            check_deps
            ensure_cluster
            build_gr_plugins
            publish_gr_plugins
            restart_purpur
            ok "Готово: gr-player-plugin обновлен и Purpur перезапущен"
            ;;
        "--gr-race")
            check_deps
            ensure_cluster
            build_gr_plugins
            publish_gr_plugins
            restart_purpur
            ok "Готово: gr-race-plugin обновлен и Purpur перезапущен"
            ;;
        "--restart-purpur")
            check_deps
            ensure_cluster
            restart_purpur
            ok "Готово: Purpur перезапущен"
            ;;
        "--help"|"help"|"")
            show_help
            ;;
        *)
            err "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
