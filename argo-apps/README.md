# Minecraft Applications Helm Chart

Этот Helm chart управляет ArgoCD Applications для Minecraft серверов.

## Параметризация destination.server

### Развёртывание в локальный кластер (по умолчанию)

По умолчанию все приложения развёртываются в тот же кластер, где установлен ArgoCD:

```yaml
destination:
  server: https://kubernetes.default.svc
  namespace: minecraft
```

### Развёртывание на удалённый кластер

Чтобы развернуть приложения на удалённый кластер (например, Golden-Ring), есть 2 способа:

#### Способ 1: Через values.yaml

Отредактировать `argo-apps/values.yaml`:

```yaml
destination:
  server: https://192.168.1.18:6443  # IP удалённого кластера
  namespace: minecraft
```

#### Способ 2: Через app-of-apps (рекомендуется)

Отредактировать `bootstrap/app-of-apps.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/balalaika7771/GR-infra.git
    targetRevision: main
    path: argo-apps
    helm:
      releaseName: minecraft-apps
      values: |
        destination:
          server: https://192.168.1.18:6443  # ← ИЗМЕНИТЬ ЗДЕСЬ
          namespace: minecraft
```

После этого все дочерние Applications (purpur, velocity, ingress-nginx) будут созданы на удалённом кластере.

## Структура

```
argo-apps/
├── Chart.yaml              # Helm chart метаданные
├── values.yaml             # Значения по умолчанию
├── README.md               # Эта инструкция
└── templates/              # Шаблоны Applications
    ├── purpur.yaml
    ├── velocity.yaml
    ├── ingress-nginx.yaml
    └── minecraft-namespace.yaml
```

## Переменные

| Параметр | Описание | Значение по умолчанию |
|----------|----------|-----------------------|
| `destination.server` | Kubernetes API сервер целевого кластера | `https://kubernetes.default.svc` |
| `destination.namespace` | Namespace для Minecraft серверов | `minecraft` |
| `repoURL` | URL Git репозитория | `https://github.com/balalaika7771/GR-infra.git` |
| `targetRevision` | Ветка/тег для синхронизации | `main` |
| `purpur.enabled` | Включить Purpur сервер | `true` |
| `purpur.persistence.enabled` | Включить PVC для Purpur | `true` |
| `purpur.persistence.storageClass` | StorageClass для PVC | `local-path` |
| `velocity.enabled` | Включить Velocity прокси | `true` |
| `ingressNginx.enabled` | Включить Ingress-Nginx | `true` |
| `minecraftNamespace.enabled` | Создать namespace minecraft | `true` |

## Примеры использования

### Тестирование шаблонов локально

```bash
helm template argo-apps/
```

### Развёртывание на Golden-Ring кластер

```bash
helm template argo-apps/ \
  --set destination.server=https://192.168.1.18:6443 \
  | kubectl apply -f -
```

### Отключение отдельных компонентов

```bash
helm template argo-apps/ \
  --set velocity.enabled=false \
  --set ingressNginx.enabled=false
```

## Регистрация удалённого кластера в ArgoCD

Перед развёртыванием на удалённый кластер, зарегистрируйте его в ArgoCD:

```bash
# Получить kubeconfig удалённого кластера
scp root@192.168.1.18:/etc/rancher/k3s/k3s.yaml goldenring-kubeconfig.yaml

# Отредактировать server URL в kubeconfig
sed -i 's|https://127.0.0.1:6443|https://192.168.1.18:6443|g' goldenring-kubeconfig.yaml

# Зарегистрировать кластер в ArgoCD
argocd cluster add goldenring \
  --kubeconfig goldenring-kubeconfig.yaml \
  --name goldenring
```

После этого можно использовать имя кластера:

```yaml
destination:
  name: goldenring  # вместо server URL
  namespace: minecraft
```

