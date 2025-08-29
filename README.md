# 🎮 Minecraft Infrastructure Project

Полностью автоматизированная инфраструктура Minecraft сервера на Kubernetes с экономической системой.

## 📋 Описание

Этот проект предоставляет готовое решение для развертывания Minecraft сервера с:
- **Velocity** - прокси сервер для балансировки нагрузки
- **Purpur** - высокопроизводительный Minecraft сервер
- **PostgreSQL** - база данных для экономики
- **Redis** - кэширование и события
- **Economy API** - микросервис экономики
- **Автоматическое создание кошельков** при входе игроков

## 🏗️ Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Игроки        │───▶│    Velocity     │───▶│     Purpur      │
│                 │    │   (Порт 30000)  │    │   (Лобби)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  Economy API    │    │   PostgreSQL    │
                       │   (Микросервис) │    │   (База данных) │
                       └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐
                       │     Redis       │
                       │   (Кэш)        │
                       └─────────────────┘
```

## 🚀 Быстрый старт

### Требования
- Kubernetes кластер (OrbStack, minikube, etc.)
- kubectl настроен и подключен к кластеру
- Helm 3.x установлен
- Docker запущен
- Gradle 8.5+ (для сборки плагинов и сервисов)

### Развертывание
```bash
# Клонируйте репозиторий
git clone <repository-url>
cd GR-infro/repo

# Запустите полное развертывание
./deploy.sh

# Подключитесь к серверу
# Адрес: localhost:30000
```

## 📚 Обзор скриптов

### `deploy.sh` - Основной скрипт развертывания
**Назначение**: Полное развертывание всей инфраструктуры с нуля

**Возможности**:
- Автоматическое создание namespace и всех компонентов
- Развертывание PostgreSQL, Redis, Velocity, Purpur
- Сборка и развертывание Economy API
- Настройка NodePort для внешнего доступа
- Проверка готовности всех сервисов

**Использование**:
```bash
./deploy.sh              # Обычное развертывание
./deploy.sh --cleanup    # Полная очистка и перезапуск
./deploy.sh --force      # Принудительное обновление
```

### `upload-plugin.sh` - Развертывание Minecraft плагина
**Назначение**: Автоматическая сборка и загрузка плагина экономики

**Возможности**:
- Maven сборка JAR файла
- Создание Docker образа
- Загрузка в локальный registry
- Копирование в pod Purpur
- Автоматический перезапуск сервера

**Использование**:
```bash
./upload-plugin.sh              # Обычная сборка и загрузка
./upload-plugin.sh --force      # Принудительная пересборка
./upload-plugin.sh --clean      # Очистка и пересборка
```

### `deploy-economy-api.sh` - Развертывание Economy API
**Назначение**: Независимое развертывание микросервиса экономики

**Возможности**:
- Maven сборка Spring Boot приложения
- Создание Docker образа
- Загрузка в registry
- Обновление Kubernetes deployment
- Проверка готовности сервиса

**Использование**:
```bash
./deploy-economy-api.sh              # Обычная сборка и развертывание
./deploy-economy-api.sh --force      # Принудительная пересборка
./deploy-economy-api.sh --clean      # Очистка и пересборка
```

### `dev-economy-api.sh` - Разработка Economy API
**Назначение**: Интерактивный режим разработки с автоматической пересборкой

**Возможности**:
- Автоматическое отслеживание изменений в коде
- Быстрая сборка и развертывание
- Мониторинг логов в реальном времени
- Проверка здоровья сервиса
- Перезапуск сервиса

**Использование**:
```bash
./dev-economy-api.sh --watch     # Автоматическая разработка
./dev-economy-api.sh --deploy    # Быстрое развертывание
./dev-economy-api.sh --logs      # Просмотр логов
./dev-economy-api.sh --health    # Проверка здоровья
```

## 🎯 Руководство по выбору скрипта

| Случай использования | Рекомендуемый скрипт | Почему |
|---------------------|---------------------|---------|
| **Продакшн развертывание** | `deploy-economy-api.sh` | Простой, надежный, готов к продакшену |
| **CI/CD пайплайн** | `deploy-economy-api.sh` | Минимальные зависимости, предсказуемость |
| **Начальная инфраструктура** | `deploy.sh` (вызывает `deploy-economy-api.sh`) | Автоматизированное полное развертывание |
| **Активная разработка** | `dev-economy-api.sh --watch` | Автоперезагрузка, комплексный мониторинг |
| **Отладка проблем** | `dev-economy-api.sh --logs` | Мониторинг логов в реальном времени |
| **Проверка здоровья** | `dev-economy-api.sh --health` | Детальная информация о здоровье |
| **Быстрое тестирование** | `dev-economy-api.sh --deploy` | Быстрый цикл сборки и развертывания |

## 🔄 Поток развертывания

```
deploy.sh
    ├── Создание namespace
    ├── Развертывание PostgreSQL
    ├── Развертывание Redis
    ├── Развертывание Registry
    ├── deploy-economy-api.sh
    │   ├── Сборка JAR
    │   ├── Docker образ
    │   ├── Загрузка в registry
    │   └── Kubernetes deployment
    ├── Развертывание Velocity
    └── Развертывание Purpur
```

## 🛠️ Обработка ошибок

### Автоматическое восстановление
- Kubernetes автоматически перезапускает упавшие поды
- Health checks обеспечивают готовность сервисов
- Rollout status проверяет успешность обновлений

### Ручное восстановление
```bash
# Проверка статуса
kubectl get pods -n minecraft

# Просмотр логов
kubectl logs -n minecraft -l app.kubernetes.io/name=economy-api

# Перезапуск сервиса
./dev-economy-api.sh --restart

# Полная очистка и перезапуск
./deploy.sh --cleanup
```

## 🧹 Заметки по очистке

### Удаленные файлы
- `port-forward.sh` - заменен на NodePort архитектуру
- `velocity.toml` - конфигурация управляется через Helm
- `forwarding.secret` - больше не требуется
- `.port-forward.pid` - автоматическое управление процессами

### Причины удаления
- **port-forward** - антипаттерн, заменен на стабильный NodePort
- **Ручная конфигурация** - заменена на Helm-управляемую
- **Временные файлы** - автоматически управляются Kubernetes

## 🔧 Конфигурация

### Порт 30000
Velocity настроен на фиксированный NodePort 30000 для стабильного доступа в OrbStack:
```yaml
service:
  type: NodePort
  port: 25565
  nodePort: 30000  # Фиксированный порт для стабильности
```

### Автоматическое создание кошельков
При входе игрока автоматически создается кошелек с 100 монетами:
- API endpoint: `POST /api/economy/ensure-wallet/{userId}`
- База данных: PostgreSQL таблица `wallets`
- Кэширование: Redis на 5 минут

## 📊 Мониторинг

### Полезные команды
```bash
# Статус всех компонентов
kubectl get pods -n minecraft

# Логи Velocity
kubectl logs -n minecraft -l app.kubernetes.io/name=velocity

# Логи Purpur
kubectl logs -n minecraft -l app.kubernetes.io/name=purpur-shard

# Логи Economy API
kubectl logs -n minecraft -l app.kubernetes.io/name=economy-api

# Статус сервисов
kubectl get svc -n minecraft
```

## 🎮 Тестирование

### Подключение к серверу
1. Запустите `./deploy.sh`
2. Подключитесь по адресу `localhost:30000`
3. Используйте команду `/balance` для проверки экономики

### API тестирование
```bash
# Создание кошелька
curl -X POST "http://localhost:8080/api/economy/ensure-wallet/test-uuid"

# Проверка баланса
curl "http://localhost:8080/api/economy/balance/test-uuid"

# Проверка здоровья
curl "http://localhost:8080/actuator/health"
```

## 🚨 Устранение неполадок

### Сервер недоступен
```bash
# Проверьте статус подов
kubectl get pods -n minecraft

# Проверьте логи Velocity
kubectl logs -n minecraft -l app.kubernetes.io/name=velocity

# Проверьте NodePort
kubectl get svc velocity -n minecraft
```

### Economy API не работает
```bash
# Проверьте статус
./dev-economy-api.sh --health

# Перезапустите сервис
./dev-economy-api.sh --restart

# Просмотрите логи
./dev-economy-api.sh --logs
```

### Плагин не загружается
```bash
# Пересоберите и загрузите плагин
./upload-plugin.sh --clean

# Проверьте логи Purpur
kubectl logs -n minecraft -l app.kubernetes.io/name=purpur-shard
```

## 📝 Лицензия

Этот проект создан для демонстрации возможностей Kubernetes и Minecraft серверов.

## 🤝 Поддержка

При возникновении проблем:
1. Проверьте логи соответствующих компонентов
2. Используйте `./deploy.sh --cleanup` для полной очистки
3. Убедитесь, что все зависимости установлены
4. Проверьте доступность Kubernetes кластера
