# GR Minecraft Infrastructure

Полная инфраструктура для Minecraft сервера с плагинами GR, включающая Kubernetes развертывание, Artifactory для артефактов и автоматизированные скрипты управления.


## Быстрый старт

### 1. Полное развертывание
```bash
# Очистка и развертывание с нуля
./deploy.sh --cleanup
./deploy.sh
```

### 2. Обновление плагинов
```bash
# Обновить все плагины и economy-api
./scripts/update.sh --all

# Обновить только определенный плагин
./scripts/update.sh --gr-core
./scripts/update.sh --gr-player
./scripts/update.sh --gr-race
./scripts/update.sh --purpur-plugin

# Обновить только economy-api
./scripts/update.sh --economy-api
```

## 📁 Структура проекта

```
repo/
├── deploy.sh                    # Основной скрипт развертывания
├── scripts/
│   ├── update.sh               # Скрипт обновления плагинов
│   └── manage-plugins.sh       # Скрипт управления плагинами
├── helm/                        # Helm charts для Kubernetes
│   ├── artifactory/            # Artifactory (Nginx + статика)
│   ├── postgres/               # PostgreSQL база данных
│   ├── redis/                  # Redis кэш
│   ├── registry/               # Docker Registry
│   ├── velocity/               # Velocity proxy
│   ├── purpur-shard/           # Purpur сервер
│   └── economy-api/            # Economy API сервис
├── plugin/
│   └── purpur-plugin/          # Основной плагин
└── services/
    └── economy-api/            # Сервис экономики
```

## Основные скрипты

### `deploy.sh` - Основной скрипт развертывания

**Назначение:** Полное развертывание инфраструктуры с нуля

**Использование:**
```bash
./deploy.sh              # Развертывание
./deploy.sh --cleanup    # Полная очистка кластера
```

**Что делает:**
1. **Инфраструктура:** Создает namespace, PostgreSQL, Redis, Registry, Artifactory
2. **Плагины:** Собирает и публикует все плагины в Artifactory
3. **Сервисы:** Развертывает Velocity, Purpur, Economy API
4. **Проверка:** Валидирует работоспособность всех сервисов


### `scripts/update.sh` - Обновление плагинов и сервисов

**Назначение:** Быстрое обновление плагинов и economy-api во время разработки

**Использование:**
```bash
./scripts/update.sh --all              # Обновить все
./scripts/update.sh --gr-core          # Только gr-core-plugin
./scripts/update.sh --gr-player        # Только gr-player-plugin
./scripts/update.sh --gr-race          # Только gr-race-plugin
./scripts/update.sh --purpur-plugin    # Только purpur-plugin
./scripts/update.sh --economy-api      # Только economy-api
./scripts/update.sh --restart-purpur   # Перезапустить Purpur
```

**Что делает:**
1. **Сборка:** Компилирует выбранные плагины/сервисы
2. **Публикация:** Загружает JAR в Artifactory
3. **Обновление:** Перезапускает соответствующие сервисы
4. **Валидация:** Проверяет успешность обновления

**Особенности:**
- Селективное обновление (только нужные компоненты)
- Автоматический перезапуск Purpur для применения плагинов
- Проверка зависимостей и кластера
- Цветной вывод с логированием

### `scripts/manage-plugins.sh` - Управление плагинами

**Назначение:** Публикация плагинов и JAR файлов в Artifactory

**Использование:**
```bash
./scripts/manage-plugins.sh publish     # Опубликовать все плагины
./scripts/manage-plugins.sh economy-api # Обновить economy-api
./scripts/manage-plugins.sh full        # Полный цикл
```

**Что делает:**
1. **Проверка:** Валидирует доступность Artifactory и Registry
2. **Сборка:** Компилирует все GR плагины
3. **Публикация:** Загружает JAR файлы в Artifactory
4. **Обновление:** Обновляет Docker образ economy-api

## Плагины

### GR Core Plugin (`gr-core-plugin/`)
- **Назначение:** Базовая функциональность для всех GR плагинов
- **Зависимости:** Bukkit API
- **Публикация:** `org.owleebr:gr-core-plugin:1.0.0`

### GR Player Plugin (`gr-player-plugin/`)
- **Назначение:** Механики игроков (статы, способности)
- **Зависимости:** `gr-core-plugin`
- **Публикация:** `org.owleebr:gr-player-plugin:1.0.0`

### GR Race Plugin (`gr-race-plugin/`)
- **Назначение:** Система рас для RPG
- **Зависимости:** `gr-core-plugin`
- **Публикация:** `org.owleebr:gr-race-plugin:1.0.0`

### Purpur Plugin (`plugin/purpur-plugin/`)
- **Назначение:** Основной плагин сервера (экономика, команды)
- **Зависимости:** `gr-core-plugin`, `gr-player-plugin`, `gr-race-plugin`
- **Публикация:** `com.example:purpur-plugin:1.0.0`

## Сервисы

### Economy API (`services/economy-api/`)
- **Назначение:** REST API для экономики сервера
- **Технологии:** Spring Boot, PostgreSQL, Redis
- **Docker:** Автоматическая сборка и публикация
- **Публикация:** `com.example:economy-api:1.0.0`

### Artifactory
- **Назначение:** Хранилище артефактов (плагины, JAR)
- **Реализация:** Nginx + статические файлы
- **Доступ:** ClusterIP (только внутри кластера)
- **Структура:**
  ```
  /minecraft-plugins/org/owleebr/gr-core-plugin/1.0.0/
  /minecraft-plugins/org/owleebr/gr-player-plugin/1.0.0/
  /minecraft-plugins/org/owleebr/gr-race-plugin/1.0.0/
  /minecraft-plugins/com/example/purpur-plugin/1.0.0/
  /economy-api/com/example/economy-api/1.0.0/
  ```

## Kubernetes особенности

### Purpur Deployment
- **Стратегия:** `Recreate` (сначала убить, потом создать)
- **Persistence:** PVC для хранения мира
- **preStop Hook:** Корректное сохранение мира перед остановкой
- **Init Containers:** Автоматическая загрузка плагинов

### Плагины
- **Загрузка:** Через init-контейнер `plugins-init`
- **Источник:** Artifactory (внутренний)
- **Конфигурация:** `plugins.yaml` (декларативно)

### Сеть
- **Velocity:** NodePort 30000 (внешний доступ)
- **Purpur:** ClusterIP (внутренний)
- **Artifactory:** ClusterIP (внутренний)
- **Registry:** ClusterIP (внутренний)

## Жизненный цикл разработки

### 1. Разработка плагина
```bash
cd gr-core-plugin
# Редактируем код
./gradlew build
```

### 2. Обновление на сервере
```bash
./scripts/update.sh --gr-core
```

### 3. Тестирование
- Подключаемся к серверу
- Проверяем функциональность
- При необходимости откатываемся
