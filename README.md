# Minecraft Infrastructure

Профессиональная инфраструктура для Minecraft сервера на базе Kubernetes с микросервисной архитектурой.

## Архитектура

### Компоненты системы

- **Velocity Proxy** - Minecraft прокси-сервер для балансировки нагрузки
- **Purpur Server** - Основной Minecraft сервер с плагинами
- **PostgreSQL** - Основная база данных для экономики и пользователей
- **Redis** - Кэш и очереди сообщений
- **Economy API** - Микросервис для управления экономикой игроков
- **Custom Plugin** - Плагин с NMS интеграцией и backend API

### Технологический стек

- **Kubernetes** - Оркестрация контейнеров
- **Helm** - Управление пакетами Kubernetes
- **Java 21** - Backend сервисы и Minecraft плагины
- **Spring Boot** - Backend фреймворк
- **PostgreSQL** - Реляционная база данных
- **Redis** - In-memory хранилище

## Быстрый старт

### Предварительные требования

- Kubernetes кластер (OrbStack, minikube, kind)
- kubectl настроен и подключен к кластеру
- helm установлен
- Java 21+ для разработки плагинов
- Maven для сборки

### Развертывание

1. **Клонирование репозитория**
   ```bash
   git clone <repository-url>
   cd repo
   ```

2. **Развертывание инфраструктуры**
   ```bash
   ./deploy.sh
   ```

3. **Загрузка плагина**
   ```bash
   ./upload-plugin.sh
   ```

4. **Подключение к серверу**
   - IP: 25565 (через port-forward или LoadBalancer)
   - Версия клиента: 1.20.1

### Очистка

Для полной очистки всех развертываний:
```bash
./deploy.sh --cleanup
```

## Детальное описание

### Helm Charts

#### PostgreSQL
- Версия: 15.x
- Пользователь: minecraft
- База данных: minecraft, economy_api
- Персистентное хранилище

#### Redis
- Версия: 7.x
- Кэш для экономики и очереди сообщений
- Персистентное хранилище

#### Velocity
- Версия: 3.3.0-SNAPSHOT
- Прокси для Minecraft 1.20.1
- Автоматическое перенаправление игроков
- Конфигурация через ConfigMap

#### Purpur Shard
- Версия: 1.20.1
- Основной Minecraft сервер
- Интеграция с Velocity
- Персистентное хранилище для мира
- Автоматическая загрузка плагинов

#### Economy API
- Spring Boot 3.2.7
- REST API для экономики
- JPA + Liquibase для миграций
- Redis интеграция
- Swagger документация

### Плагин

#### Функциональность
- Автоматическое создание кошельков для новых игроков
- Команды: /balance, /transfer, /auth, /ping, /nms
- NMS интеграция для продвинутых функций
- Backend API интеграция

#### Архитектура плагина
- Bukkit API 1.20.1
- NMS утилиты для низкоуровневых операций
- HTTP клиент для backend API
- Redis подписчик для событий
- Асинхронная обработка

### Сетевая архитектура

#### Сервисы
- **ClusterIP** для внутренних сервисов
- **LoadBalancer** для внешнего доступа к Velocity
- **Port-forwarding** для локальной разработки

#### Порты
- Velocity: 25565 (внешний)
- Economy API: 8080 (внутренний)
- PostgreSQL: 5432 (внутренний)
- Redis: 6379 (внутренний)

## Разработка

### Локальная разработка

1. **Запуск кластера**
   ```bash
   # OrbStack
   orb start
   
   # minikube
   minikube start
   
   # kind
   kind create cluster
   ```

2. **Развертывание**
   ```bash
   ./deploy.sh
   ```

3. **Разработка плагина**
   ```bash
   cd plugin/purpur-plugin
   mvn clean compile
   mvn package
   ```

4. **Загрузка плагина**
   ```bash
   ./upload-plugin.sh
   ```

### Отладка

#### Логи сервисов
```bash
# Velocity
kubectl logs -n minecraft -l app.kubernetes.io/name=velocity

# Purpur
kubectl logs -n minecraft -l app.kubernetes.io/name=purpur-shard

# Economy API
kubectl logs -n minecraft -l app.kubernetes.io/name=economy-api
```

#### Подключение к базе данных
```bash
kubectl exec -n minecraft deployment/postgres -- psql -U minecraft -d economy_api
```

#### Port-forward для локального доступа
```bash
# Velocity
kubectl port-forward -n minecraft svc/velocity 25565:25565

# Economy API
kubectl port-forward -n minecraft svc/economy-api 8080:8080
```

## Мониторинг и логирование

### Health Checks
- Spring Boot Actuator для Economy API
- Kubernetes readiness/liveness probes
- Автоматический restart при сбоях

### Логирование
- Структурированные логи в JSON формате
- Централизованное логирование через kubectl
- Ротация логов для экономии места

## Безопасность

### Аутентификация
- Mojang UUID для игроков
- Отключен online-mode для локальной разработки
- Velocity forwarding secret для безопасности

### Сетевая безопасность
- Изолированные namespace
- Внутренние сервисы недоступны извне
- Только Velocity доступен внешне

## Масштабирование

### Горизонтальное масштабирование
- Velocity: до 3 реплик для балансировки
- Purpur: до 5 шардов для распределения игроков
- Economy API: до 10 реплик для высокой нагрузки

### Вертикальное масштабирование
- Настройка ресурсов через values.yaml
- Автоматическое масштабирование по CPU/Memory
- HPA (Horizontal Pod Autoscaler) поддержка

## Резервное копирование

### База данных
- Автоматические бэкапы PostgreSQL
- Персистентные тома для данных
- Возможность восстановления из снапшотов

### Мир Minecraft
- Персистентное хранение мира
- Автоматическое сохранение каждые 5 минут
- Возможность ручного сохранения через RCON

## Troubleshooting

### Частые проблемы

#### Pod не запускается
```bash
kubectl describe pod <pod-name> -n minecraft
kubectl logs <pod-name> -n minecraft
```

#### Проблемы с подключением
```bash
# Проверка сервисов
kubectl get svc -n minecraft

# Проверка endpoints
kubectl get endpoints -n minecraft
```

#### Проблемы с плагином
```bash
# Пересборка и загрузка
./upload-plugin.sh

# Проверка логов
kubectl logs -n minecraft -l app.kubernetes.io/name=purpur-shard
```

### Восстановление

#### Полная переустановка
```bash
./deploy.sh --cleanup
./deploy.sh
```

#### Восстановление плагина
```bash
./upload-plugin.sh
```

## Лицензия

Проект распространяется под лицензией MIT.

## Поддержка

Для получения поддержки создайте issue в репозитории или обратитесь к команде разработки.
