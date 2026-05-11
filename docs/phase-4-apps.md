# Фаза 4 — Приложения CaseGo в кластере

Цель: 5 сервисов работают в K8s, доступны по `<service>.<ip>.nip.io` с HTTPS,
БД содержат seed-данные (одна тестовая учётка + один кейс).

## Что появится

```
apps/
├── databases/
│   ├── postgres-auth.yaml
│   ├── postgres-profile.yaml
│   ├── postgres-casego.yaml
│   ├── postgres-caseprofile.yaml
│   ├── postgres-payment.yaml
│   ├── redis-casego.yaml
│   └── seed-configmaps.yaml
├── auth/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
├── profile/
├── casego/
├── caseprofile/
├── payment/
└── secrets/
    ├── auth.enc.yaml       # OAuth client_id/secret, JWT private key
    ├── casego.enc.yaml     # LLM API key, Redis password
    └── *.enc.yaml          # DB passwords (если не из ConfigMap)
```

## Особенности

- **Postgres-деплои с emptyDir** — данные не сохраняются после удаления пода.
  При создании пода `initContainer` накатывает миграции (используем образ
  `migrate/migrate` как в docker-compose) + второй init заливает seed.sql.
- **JWT-ключи (RS256)** — приватный ключ только для Auth (через SOPS-секрет),
  публичный — в ConfigMap всех остальных сервисов.
- **gRPC между CaseGo и CaseProfile** — оба в одном namespace, `Service` имени
  `case-profile:50051`. Self-signed mTLS-сертификаты сейчас генерируются через
  `certs-gen` init-контейнер из docker-compose. В K8s заменим на CronJob или
  один раз руками в SOPS-секрет.
- **gRPC между CaseGo и Payment** — аналогично.
- **CORS** на бэкенде расширяем: текущий домен фронта + `*.nip.io` для прямого
  тестирования API через Swagger.
- **OAuth callback URL** в Google Console добавить
  `https://auth.<ip>.nip.io/api/v1/auth/google/callback`.

## Образы

Все образы тянутся из GHCR (как сейчас в docker-compose):

```
ghcr.io/sewaustav/casego-auth:latest
ghcr.io/sewaustav/casego-profile:latest
ghcr.io/sewaustav/casego-casego:latest
ghcr.io/sewaustav/casego-caseprofile:latest
ghcr.io/sewaustav/casego-payment:latest
```

Если репозиторий приватный — добавим `imagePullSecret` через SOPS.
