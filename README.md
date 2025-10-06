## Инфраструктура: Argo CD + Helm (purpur, velocity)

### Параметры
- **REPO_GIT_URL**: `https://github.com/balalaika7771/GR-infra.git`
- **STORAGE_CLASS_NAME**: `local-path`
- **ARGOCD_DOMAIN**: `argocd.185.176.94.66.nip.io`

### Состав
- Чарты: `charts/purpur`, `charts/velocity`
- Bootstrap Argo CD: `bootstrap/` (Namespace, установка, Ingress, app-of-apps)
- Приложения Argo CD: `argo-apps/` (`purpur`, `velocity` в namespace `minecraft`)

### Деплой
```bash
cd gr-infro
chmod +x deploy.sh
./deploy.sh
```

Argo CD веб: `https://argocd.185.176.94.66.nip.io`
Пароль `admin`:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

### Примечания
- `purpur` использует PVC со `storageClass: local-path`.
- init-container у `purpur` удалён по требованию.
- `velocity` слушает NodePort `30000` (можно заменить на LoadBalancer, если доступен).

