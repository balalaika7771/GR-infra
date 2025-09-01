#!/bin/bash

# Скрипт для быстрой настройки WSL2 для Minecraft Infrastructure
# Запускать в WSL2 Ubuntu

set -e

echo "🚀 Настройка WSL2 для Minecraft Infrastructure..."

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка, что мы в WSL2
if ! grep -q microsoft /proc/version; then
    error "Этот скрипт предназначен для WSL2"
    exit 1
fi

success "WSL2 обнаружен"

# Обновление системы
log "Обновление системы..."
sudo apt update && sudo apt upgrade -y
success "Система обновлена"

# Установка базовых инструментов
log "Установка базовых инструментов..."
sudo apt install -y curl wget git unzip
success "Базовые инструменты установлены"

# Установка kubectl
log "Установка kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    success "kubectl установлен"
else
    success "kubectl уже установлен"
fi

# Установка Helm
log "Установка Helm..."
if ! command -v helm &> /dev/null; then
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable.list
    sudo apt update
    sudo apt install -y helm
    success "Helm установлен"
else
    success "Helm уже установлен"
fi

# Установка Java 21
log "Установка Java 21..."
if ! command -v java &> /dev/null || ! java -version 2>&1 | grep -q "21"; then
    sudo apt install -y openjdk-21-jdk
    success "Java 21 установлен"
else
    success "Java 21 уже установлен"
fi

# Установка Gradle
log "Установка Gradle..."
if ! command -v gradle &> /dev/null; then
    sudo apt install -y gradle
    success "Gradle установлен"
else
    success "Gradle уже установлен"
fi

# Проверка Docker
log "Проверка Docker..."
if ! command -v docker &> /dev/null; then
    warning "Docker не установлен в WSL2"
    warning "Установите Docker Desktop для Windows и включите WSL2 integration"
    warning "Или используйте: curl -fsSL https://get.docker.com | sh"
else
    success "Docker доступен"
    
    # Настройка прав доступа к Docker
    log "Настройка прав доступа к Docker..."
    if ! groups $USER | grep -q docker; then
        sudo usermod -aG docker $USER
        log "Пользователь добавлен в группу docker"
        warning "Необходимо перезапустить WSL2 или выполнить: newgrp docker"
    else
        success "Пользователь уже в группе docker"
    fi
    
    # Проверка подключения к Docker daemon
    if ! docker info &> /dev/null; then
        warning "Нет доступа к Docker daemon"
        log "Попытка исправить права доступа..."
        if [ -S /var/run/docker.sock ]; then
            sudo chmod 666 /var/run/docker.sock
            if docker info &> /dev/null; then
                success "Права доступа к Docker daemon исправлены"
            else
                warning "Не удалось исправить права доступа"
                warning "Попробуйте перезапустить WSL2 или Docker Desktop"
            fi
        else
            warning "Docker socket не найден"
            warning "Убедитесь, что Docker Desktop запущен"
        fi
    else
        success "Docker daemon доступен"
    fi
fi

# Проверка Kubernetes кластера
log "Проверка Kubernetes кластера..."
if ! kubectl cluster-info &> /dev/null; then
    warning "Kubernetes кластер недоступен"
    echo ""
    echo "Для запуска кластера выберите один из вариантов:"
    echo "1. Docker Desktop: включите Kubernetes в настройках"
    echo "2. Minikube: minikube start --driver=docker"
    echo "3. Kind: kind create cluster"
else
    success "Kubernetes кластер доступен"
fi

# Финальная проверка
echo ""
echo "================================================================================"
echo "                    ПРОВЕРКА УСТАНОВКИ"
echo "================================================================================"
echo ""

# Проверяем версии
echo "Версии установленных компонентов:"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || echo 'не установлен')"
echo "  helm: $(helm version --short 2>/dev/null || echo 'не установлен')"
echo "  java: $(java -version 2>&1 | head -1 || echo 'не установлен')"
echo "  gradle: $(gradle --version 2>/dev/null | head -1 || echo 'не установлен')"
echo "  docker: $(docker --version 2>/dev/null || echo 'не установлен')"

echo ""
echo "================================================================================"
echo "                    СЛЕДУЮЩИЕ ШАГИ"
echo "================================================================================"
echo ""
echo "1. Убедитесь, что Docker Desktop запущен и Kubernetes включен или запустите minikube: minikube start --driver=docker"
echo "2. Перейдите в директорию: cd GR-infro"
echo "3. Сделайте скрипты исполняемыми: chmod +x deploy.sh scripts/*.sh"
echo "4. Запустите развертывание: ./deploy.sh"
echo ""
echo "================================================================================"
echo ""

success "Настройка WSL2 завершена!"
