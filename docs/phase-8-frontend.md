# Фаза 8 — Фронтенд в кластере (два окружения)

Цель: фронт (Flutter web + nginx) работает и на VPS (dev), и в k8s (prod).
**Образ один и тот же** — `ghcr.io/sewaustav/casego-frontend`; различается только
nginx-конфиг, который в k8s подменяется через ConfigMap.

## Окружения

| | VPS (dev) | K8s (prod) |
|---|---|---|
| Деплой | CI по SSH, docker compose | Flux + image automation |
| Тег образа | `latest` | `main-<run>-<sha>` (пиннится автоматикой) |
| TLS | certbot на хосте, nginx :443 | ingress-nginx + cert-manager |
| nginx-конфиг | запечён в образ | ConfigMap `frontend-nginx` |
| Апстримы API | docker-имена контейнеров | k8s-сервисы (`auth:8000`, …) |
| URL | <https://casego.ddns.net> | <https://front.158-160-192-124.nip.io> |

## Что появилось

```
apps/frontend/
├── configmap.yaml      # k8s-вариант nginx.conf (listen 80, прокси на сервисы)
├── deployment.yaml     # + imagepolicy-маркер
├── service.yaml
├── ingress.yaml        # front.<ip>.nip.io + Let's Encrypt
└── kustomization.yaml
```

Плюс `ImageRepository`/`ImagePolicy` casego-frontend в image-automation и
тег `main-<run>-<sha>` в CI фронта.

## Как это работает

Браузер → ingress-nginx (TLS) → под фронта, где nginx раздаёт статику Flutter
и проксирует `/api/v1/*`, `/profile/api/v1/*` на сервисы в том же namespace.
API и фронт same-origin → CORS не нужен. Запечённый в образ VPS-конфиг
перекрыт маунтом ConfigMap в `/etc/nginx/conf.d/default.conf`.

## Порядок первого деплоя (важно)

1. Сначала пуш во фронт-репо → CI собирает образ с тегом `main-<run>-<sha>`.
2. Потом пуш gitops — иначе ImagePolicy без подходящих тегов держит
   `infrastructure` в NotReady.
3. Deployment стартует с `:latest`, автоматика тут же пиннит его на
   `main-<run>-<sha>`.

## Проверка

```bash
kubectl -n casego-apps get pods -l app=frontend
kubectl get certificate -n casego-apps frontend-tls
curl -s -o /dev/null -w "%{http_code}\n" https://front.158-160-192-124.nip.io
```

## Нюанс: Google OAuth

Вход через Google на k8s-домене заработает только после добавления
`https://front.158-160-192-124.nip.io/...callback` в Authorized redirect URIs
в Google Cloud Console (как сделано для casego.ddns.net).
