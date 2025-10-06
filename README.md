# mc-infra-argocd

Инфраструктура Minecraft: ingress-nginx → Velocity → Purpur, управляется через Argo CD (App-of-Apps). Наружу торчит TCP-порт 25565 и веб-интерфейс Argo CD.

## Быстрый старт
1) Укажи свои значения в:
   - ingress-nginx/values.yaml (тип сервиса, аннотации облака, опционально static IP)
   - ingress-nginx/tcp-services-configmap.yaml (namespace совпадает с ниже)
   - charts/*/values.yaml (ресурсы, storageClass, размеры PVC)
   - bootstrap/20-argocd-ingress.yaml (домен ARGOCD_DOMAIN)
2) Разверни Argo CD:

```
kubectl apply -f bootstrap/00-namespace.yaml
kubectl apply -f bootstrap/10-argocd-install.yaml
kubectl apply -f bootstrap/20-argocd-ingress.yaml

```
Первичный пароль: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`
3) В Argo CD добавь репозиторий Git с этим кодом и синхронизируй `minecraft-apps` (app-of-apps).
4) Пропиши DNS:
- `A` для ARGOCD_DOMAIN → внешний IP ingress-nginx (или LB IP)
- для Minecraft можно использовать IP:порт напрямую или настроить SRV `_minecraft._tcp.MC_DOMAIN` → 25565

## Обновление Purpur/Velocity
- Версии управляются переменными образа/окружения в `argo-apps/velocity.yaml` и `argo-apps/purpur.yaml`, а также в соответствующих `charts/*/values.yaml`:
  - Velocity использует образ `ghcr.io/itzg/minecraft-server` с `TYPE=VELOCITY` и `VELOCITY_VERSION=LATEST`.
  - Purpur использует образ `itzg/minecraft-server` с `TYPE=PURPUR` и `EULA=TRUE`.
- Плагины можно помещать в PVC по пути `/data/plugins`.

## SRV-запись
Пример SRV-записи для домена MC_DOMAIN:

```
_minecraft._tcp.MC_DOMAIN 0 5 25565 A_RECORD_OF_INGRESS
```

Это указывает клиентам Minecraft использовать TCP-порт 25565 хоста, на который указывает A-запись.

## TLS для Argo CD
Для подключения TLS через cert-manager (пример с ClusterIssuer `letsencrypt`):
1) Установи cert-manager (без включения метрик, если они не нужны). См. официальную документацию.
2) Создай ClusterIssuer (пример):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

3) В `bootstrap/20-argocd-ingress.yaml` добавь аннотации cert-manager и секцию `spec.tls`, например:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt"
spec:
  tls:
  - hosts:
    - argocd.185.176.94.66.nip.io
    secretName: argocd-tls
```

После применения сертификат будет автоматически выпущен, а доступ к Argo CD будет по HTTPS.


