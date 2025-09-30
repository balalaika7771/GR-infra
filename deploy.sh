#!/bin/bash

# Minecraft Infrastructure Deployment Script
# Supports Kubernetes (OrbStack) with full cleanup capabilities
# Uses NodePort architecture for stable external access

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
HELM_DIR="helm"


# Проверка и исправление Docker прав
check_docker_access() {
    if command -v docker &> /dev/null; then
        if ! docker info &> /dev/null; then
            warning "Нет доступа к Docker daemon"
            log "Попытка исправить права доступа..."
            if [ -S /var/run/docker.sock ]; then
                sudo chmod 666 /var/run/docker.sock
                if docker info &> /dev/null; then
                    success "Права доступа к Docker daemon исправлены"
                else
                    error "Не удалось исправить права доступа к Docker"
                    exit 1
                fi
            else
                error "Docker socket не найден. Убедитесь, что Docker Desktop запущен"
                exit 1
            fi
        else
            success "Docker daemon доступен"
        fi
    fi
}

# Проверка зависимостей
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes cluster is not accessible"
        exit 1
    fi
    
    success "All dependencies verified"
}

# Безопасное применение Helm релиза с авто-очисткой зависших операций
helm_safe_upgrade() {
    local release="$1"
    local chart="$2"
    shift 2
    local extra_args=("$@")

    for attempt in 1 2; do
        if helm upgrade --install "$release" "$chart" -n "$NAMESPACE" "${extra_args[@]}"; then
            return 0
        fi

        # Проверяем, не завис ли релиз в pending-*
        if helm status "$release" -n "$NAMESPACE" 2>/dev/null | grep -qiE 'pending-(install|upgrade|rollback)'; then
            warning "Helm release '$release' застрял в pending. Выполняю принудительную очистку и повторю..."
            # Мягкое удаление релиза без хуков
            helm uninstall "$release" -n "$NAMESPACE" --no-hooks || true
            # Удаляем возможные остатки метаданных helm
            kubectl -n "$NAMESPACE" delete secret,configmap -l "owner=helm,name=$release" --ignore-not-found=true 2>/dev/null || true
            # Удаляем застрявшие jobs/pods этого релиза
            kubectl -n "$NAMESPACE" delete job -l "release=$release" --ignore-not-found=true 2>/dev/null || true
            sleep 5
            continue
        fi

        # Если причина не в pending, пробуем один раз принудительно переустановить
        warning "Повторная попытка установки '$release' после очистки остатков"
        helm uninstall "$release" -n "$NAMESPACE" --no-hooks || true
        kubectl -n "$NAMESPACE" delete secret,configmap -l "owner=helm,name=$release" --ignore-not-found=true 2>/dev/null || true
        sleep 3
    done

    error "Не удалось установить/обновить Helm release '$release'"
    return 1
}

# Установка/проверка Java для сборки внутренних артефактов
ensure_java() {
    if command -v java &> /dev/null; then
        success "Java обнаружена: $(java -version 2>&1 | head -n1)"
        return
    fi
    log "Java не обнаружена. Устанавливаю OpenJDK 21..."
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y || {
            warning "apt-get update завершился с ошибкой. Пробую удалить проблемный helm-репозиторий и повторить..."
            rm -f /etc/apt/sources.list.d/helm-stable-debian.list 2>/dev/null || true
            apt-get update -y
        }
        apt-get install -y ca-certificates openjdk-21-jdk-headless
        update-ca-certificates || true
    else
        error "apt-get не найден. Установите Java вручную или добавьте менеджер пакетов."
        exit 1
    fi
    if ! command -v java &> /dev/null; then
        error "Java не установилась корректно"
        exit 1
    fi
    # Экспортируем JAVA_HOME если каталог известен
    if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
    success "Java установлена: $(java -version 2>&1 | head -n1)"
}

# Показать справку
show_help() {
    echo "================================================================================"
    echo "                    MINECRAFT INFRASTRUCTURE DEPLOYMENT"
    echo "================================================================================"
    echo ""
    echo "DESCRIPTION:"
    echo "  Automated deployment script for Minecraft infrastructure on Kubernetes"
    echo "  Uses NodePort architecture for stable external access"
    echo ""
    echo "USAGE: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h     Show this help message"
    echo "  --cleanup      Remove all deployments from cluster"
    echo ""
    echo "EXAMPLES:"
    echo "  $0              Deploy infrastructure"
    echo "  $0 --cleanup    Clean up all deployments"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Kubernetes cluster (OrbStack, minikube, etc.)"
    echo "  - kubectl configured and connected to cluster"
    echo "  - helm installed"
    echo "  - Internet access for image downloads"
    echo ""
    echo "COMPONENTS:"
    echo "  - PostgreSQL (Database)"
    echo "  - Redis (Cache & Queues)"
    echo "  - Velocity (Minecraft Proxy) - NodePort:30000"
    echo "  - Purpur (Minecraft Server)"
    echo "  - Economy API (Microservice)"
    echo ""
    echo "PORTS:"
    echo "  - Velocity: 30000 (External NodePort)"
    echo "  - Economy API: 8080 (Internal)"
    echo "  - PostgreSQL: 5432 (Internal)"
    echo "  - Redis: 6379 (Internal)"
    echo ""
    echo "ARCHITECTURE:"
    echo "  - NodePort Service for stable external access"
    echo "  - No port-forward required"
    echo "  - Automatic recovery and scaling"
    echo "  - Kubernetes native design"
    echo "================================================================================"
}

# Очистка развертываний
cleanup() {
    echo ""
    echo "================================================================================"
    echo "                           ПОЛНАЯ ОЧИСТКА КЛАСТЕРА"
    echo "================================================================================"
    echo ""
    
    log "Начинаю полную очистку кластера..."
    
    # Останавливаем все port-forward процессы
    log "Останавливаю все port-forward процессы..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 3
    
    # Удаляем все Helm релизы
    log "Удаляю Helm релизы..."
    helm uninstall purpur-lobby -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall velocity -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall economy-api -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall redis -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall postgres -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall registry -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    helm uninstall artifactory -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    success "Helm релизы удалены"
    
    # Ждем завершения удаления Helm релизов
    log "Ожидаю завершения удаления Helm релизов..."
    sleep 10
    
    # Удаляем все ресурсы из namespace
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log "Удаляю все ресурсы из namespace $NAMESPACE..."
        
        # Удаляем deployments
        kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем services
        kubectl delete service --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем pods
        kubectl delete pod --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем PVC
        kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем ConfigMaps
        kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        
        # Удаляем namespace
        log "Удаляю namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        success "Namespace $NAMESPACE удален"
    else
        log "Namespace $NAMESPACE не найден, пропускаю"
    fi
    
    # Ждем полного удаления и очищаем кэш
    log "Ожидаю завершения очистки..."
    sleep 15
    
    # Очищаем Docker образы если они есть
    log "Очищаю Docker образы..."
    docker rmi localhost:30500/economy-api:latest 2>/dev/null || true
    docker rmi localhost:30500/economy-api:dev-* 2>/dev/null || true
    docker rmi localhost:30500/economy-plugin:latest 2>/dev/null || true
    docker rmi economy-api:dev-* 2>/dev/null || true
    docker rmi economy-api:base 2>/dev/null || true
    
    # Очищаем временные файлы
    log "Очищаю временные файлы..."
    rm -f .economy-api-image 2>/dev/null || true
    
    echo ""
    echo "================================================================================"
    echo "  КЛАСТЕР ПОЛНОСТЬЮ ОЧИЩЕН"
    echo "  Все развертывания удалены из кластера"
    echo "================================================================================"
    echo ""
}

# Основная функция развертывания
deploy() {
    echo ""
    echo "================================================================================"
    echo "                    DEPLOYING MINECRAFT INFRASTRUCTURE"
    echo "================================================================================"
    echo ""
    
    log "Starting deployment process..."
    
    # Проверяем зависимости
    check_dependencies
    
    # Проверяем доступ к Docker
    check_docker_access
    
    # Создаем namespace
    log "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    success "Namespace $NAMESPACE created"
    
    # Устанавливаем Helm chart: registry
    log "Installing Helm chart: registry"
    helm_safe_upgrade registry ./helm/registry --wait --timeout=180s
    success "Registry deployed"
    
    # Устанавливаем MinIO (object storage)
    log "Installing Helm chart: minio"
    helm_safe_upgrade minio ./helm/minio --wait --timeout=600s
    success "MinIO deployed (API NodePort 30090, Console NodePort 30091)"

    # Устанавливаем NGINX Router (HTTP reverse-proxy + TCP 25565→Velocity)
    log "Installing Helm chart: nginx-router"
    helm_safe_upgrade nginx-router ./helm/nginx-router --wait --timeout=300s
    success "NGINX Router deployed (HTTP NodePort 30080, MC NodePort 30000)"

    # Устанавливаем Artifactory
    log "Installing Helm chart: artifactory"
    helm_safe_upgrade artifactory ./helm/artifactory --wait --timeout=600s
    success "Artifactory deployed"
    
    # Развертываем PostgreSQL
    log "Deploying PostgreSQL..."
    helm_safe_upgrade postgres $HELM_DIR/postgres \
        --set persistence.storageClass=hostpath \
        --wait --timeout=600s
    success "PostgreSQL deployed"
    
    # Развертываем Redis
    log "Deploying Redis..."
    helm_safe_upgrade redis $HELM_DIR/redis --wait
    success "Redis deployed"
    
    # Ждем готовности баз данных
    log "Waiting for PostgreSQL readiness..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n $NAMESPACE --timeout=600s
    
    # Дополнительная проверка готовности PostgreSQL
    log "Verifying PostgreSQL connection..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if kubectl exec -n $NAMESPACE deployment/postgres -- pg_isready -U minecraft -d minecraft &>/dev/null; then
            success "PostgreSQL is ready"
            break
        fi
        log "PostgreSQL not ready yet, waiting... (attempt $((retries+1))/30)"
        sleep 10
        retries=$((retries+1))
    done
    
    if [ $retries -eq 30 ]; then
        error "PostgreSQL did not become ready within timeout"
        exit 1
    fi
    
    # Создаем базы данных (они уже созданы через initScripts в Helm чарте)
    log "Checking databases auth_bridge and economy_api..."
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "\\l" | grep -E "(auth_bridge|economy_api)" || {
        warning "Databases not found, creating them..."
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE auth_bridge;" 2>/dev/null || true
        kubectl exec -n $NAMESPACE deployment/postgres -- psql -U minecraft -d minecraft -c "CREATE DATABASE economy_api;" 2>/dev/null || true
    }
    success "Databases ready"
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n $NAMESPACE --timeout=300s
    success "Redis ready"
    
    # Развертываем Velocity
    log "Deploying Velocity proxy..."
    helm_safe_upgrade velocity $HELM_DIR/velocity --wait
    success "Velocity deployed"
    
    # Настройка доступа к Velocity
    log "Configuring Velocity access..."
    
    # Получаем информацию о NodePort сервисе
    log "Checking NodePort service..."
    NODE_PORT=$(kubectl get svc velocity -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$NODE_PORT" ]; then
        success "Velocity configured on NodePort: $NODE_PORT"
        success "Server accessible at localhost:$NODE_PORT"
    else
        warning "NodePort not configured, check service: kubectl get svc velocity -n $NAMESPACE"
    fi
    
    # Публикуем ТОЛЬКО внутренние артефакты и собираем образ Economy API ПЕРЕД развертыванием
    log "Publishing internal artifacts (purpur-plugin, economy-api) and building Economy API image..."
    
    # Ждем готовности artifactory (теперь ClusterIP)
    log "Waiting for artifactory to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=artifactory -n $NAMESPACE --timeout=300s || true
    success "artifactory ready (internal access only)"
    # Гарантируем наличие Java для gradle wrapper
    ensure_java
    # Определяем pod artifactory
    ARTIFACTORY_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=artifactory -o jsonpath='{.items[0].metadata.name}') || ARTIFACTORY_POD=""
    if [ -z "$ARTIFACTORY_POD" ]; then
        error "Artifactory pod not found in namespace $NAMESPACE"
        exit 1
    fi

    # 1) purpur-plugin (внутренний)
    log "Building and publishing purpur-plugin..."
    if [ -d "plugin/purpur-plugin" ]; then
        pushd plugin/purpur-plugin >/dev/null
        if [ -f "gradlew" ]; then
            chmod +x gradlew || true
            ./gradlew clean build
            PLUGIN_JAR="build/libs/purpur-plugin-1.0.0.jar"
            if [ -f "$PLUGIN_JAR" ]; then
                kubectl exec -n "$NAMESPACE" "$ARTIFACTORY_POD" -- mkdir -p /usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0
                kubectl cp "$PLUGIN_JAR" "$NAMESPACE/$ARTIFACTORY_POD:/usr/share/nginx/html/minecraft-plugins/com/example/purpur-plugin/1.0.0/purpur-plugin-1.0.0.jar"
                success "purpur-plugin published to Artifactory"
            else
                warning "purpur-plugin jar not found: $PLUGIN_JAR"
            fi
        else
            warning "Gradle wrapper not found for purpur-plugin"
        fi
        popd >/dev/null
    else
        warning "Directory plugin/purpur-plugin not found, skipping"
    fi

    # 2) economy-api (внутренний)
    log "Building and publishing economy-api JAR..."
    if [ -d "services/economy-api" ]; then
        pushd services/economy-api >/dev/null
        if [ -f "gradlew" ]; then
            chmod +x gradlew || true
            ./gradlew clean build
            ECONOMY_JAR="build/libs/economy-api-1.0.0.jar"
            if [ -f "$ECONOMY_JAR" ]; then
                kubectl exec -n "$NAMESPACE" "$ARTIFACTORY_POD" -- mkdir -p /usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0
                kubectl cp "$ECONOMY_JAR" "$NAMESPACE/$ARTIFACTORY_POD:/usr/share/nginx/html/economy-api/com/example/economy-api/1.0.0/economy-api-1.0.0.jar"
                success "economy-api JAR published to Artifactory"
            else
                warning "economy-api jar not found: $ECONOMY_JAR"
            fi
        else
            warning "Gradle wrapper not found for economy-api"
        fi
        popd >/dev/null
    else
        warning "Directory services/economy-api not found, skipping"
    fi

    # 3) In-cluster build: Kaniko Job -> push to registry ClusterIP
    log "Building Economy API image inside cluster with Kaniko..."
    TAG="1.0.0-$(date +%Y%m%d%H%M%S)"
    ARTIFACT_URL="http://artifactory.minecraft.svc.cluster.local/economy-api/com/example/economy-api/1.0.0/economy-api-1.0.0.jar"

    cat <<'KANIKO' | kubectl apply -n $NAMESPACE -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build-economy-api
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - "--dockerfile=/workspace/repo/services/economy-api/Dockerfile"
            - "--context=/workspace"
            - "--destination=registry.minecraft.svc.cluster.local:5000/economy-api:${TAG}"
            - "--build-arg=ARTIFACT_URL=${ARTIFACT_URL}"
            - "--skip-tls-verify=true"
          env:
            - name: DOCKER_CONFIG
              value: /kaniko/.docker
          volumeMounts:
            - name: workspace
              mountPath: /workspace
      volumes:
        - name: workspace
          hostPath:
            path: /opt/infra
            type: Directory
KANIKO

    # Ждем завершения job
    kubectl -n $NAMESPACE wait --for=condition=complete job/kaniko-build-economy-api --timeout=1200s
    kubectl -n $NAMESPACE delete job kaniko-build-economy-api --ignore-not-found=true

    # Сохраняем тег для использования в Helm
    echo "$TAG" > .economy-api-image-tag
    success "Economy API image built and pushed in-cluster: registry:5000/economy-api:$TAG"
    
    # Развертываем Purpur (теперь плагины уже в Artifactory)
    log "Deploying Purpur shard..."
    helm_safe_upgrade purpur-lobby $HELM_DIR/purpur-shard \
        --set persistence.storageClass=hostpath \
        --wait --timeout=600s
    success "Purpur deployed"
    
    # Ждем готовности сервисов
    log "Waiting for services readiness..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velocity -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=purpur-shard -n $NAMESPACE --timeout=300s
    success "Services ready"
    
    # Развертываем economy-api через Helm с готовым образом
    log "Deploying economy-api..."
    if [ -f ".economy-api-image-tag" ]; then
        IMAGE_TAG=$(cat .economy-api-image-tag)
        log "Using pre-built image: registry:5000/economy-api:$IMAGE_TAG"
        helm_safe_upgrade economy-api $HELM_DIR/economy-api \
            --set image.repository=registry:5000/economy-api \
            --set image.tag="$IMAGE_TAG" \
            --set image.pullPolicy=Always \
            --wait --timeout=600s
    else
        # Fallback если тег не найден
        helm_safe_upgrade economy-api $HELM_DIR/economy-api --wait --timeout=600s
    fi
    success "economy-api deployed"
    
    # Ждем готовности economy-api
    log "Waiting for economy-api readiness..."
    kubectl wait --for=condition=ready pod -l app=economy-api -n $NAMESPACE --timeout=300s || {
        warning "economy-api not ready, but continuing deployment"
    }
    
    # Финальная проверка всех сервисов
    log "Final verification of all services..."
    local all_ready=true
    
    # Проверяем Velocity
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=velocity --field-selector=status.phase=Running | grep -q "1/1"; then
        success "Velocity is running"
    else
        warning "Velocity may not be ready"
        all_ready=false
    fi
    
    # Проверяем Purpur
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard --field-selector=status.phase=Running | grep -q "1/1"; then
        success "Purpur is running"
    else
        warning "Purpur may not be ready"
        all_ready=false
    fi
    
    # Проверяем economy-api
    if kubectl get pods -n $NAMESPACE -l app=economy-api --field-selector=status.phase=Running | grep -q "1/1"; then
        success "Economy API is running"
    else
        warning "Economy API may not be ready"
        all_ready=false
    fi
    
    if [ "$all_ready" = true ]; then
        success "All core services are running"
    else
        warning "Some services may need time to become ready"
    fi
    
    success "Deployment completed successfully!"
    
    # Получаем информацию о подключении
    echo ""
    echo "================================================================================"
    echo "                    MINECRAFT SERVER READY FOR CONNECTION"
    echo "================================================================================"
    echo ""
    if [ -n "$NODE_PORT" ]; then
        echo "  SERVER ADDRESS: localhost:$NODE_PORT"
        echo "  CONNECTION TYPE: NodePort Service (Stable)"
        echo "  STATUS: Ready"
        echo ""
        echo "  FEATURES:"
        echo "    - No port-forward required"
        echo "    - Fixed port number"
        echo "    - Automatic recovery"
        echo "    - Kubernetes native"
    else
        echo "  STATUS: Warning - NodePort not configured"
        echo "  ACTION: Check service status: kubectl get svc velocity -n $NAMESPACE"
    fi
    echo ""
    echo "================================================================================"
    echo "  NEXT STEPS:"
    echo "    1. Check pod status: kubectl get pods -n $NAMESPACE"
    echo "    2. Connect to server: localhost:$NODE_PORT"
    echo "    3. Economy API running automatically"
    echo "    4. Plugins managed via: ./scripts/manage-plugins.sh"
    echo ""
    echo "  USEFUL COMMANDS:"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=velocity"
    echo "    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=purpur-shard"
    echo "    kubectl get svc velocity -n $NAMESPACE"
    echo "    ./scripts/manage-plugins.sh help"
    echo "================================================================================"
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
            error "Unknown option: $1"
            echo "Use $0 --help for usage information"
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
