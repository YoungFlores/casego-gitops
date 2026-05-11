# casego-gitops

GitOps-репозиторий для Kubernetes-кластера CaseGo в Yandex Cloud.

Стратегия: **эфемерный кластер**. Кластер создаётся через Terraform за 5-7 минут,
Flux при поднятии подтягивает все манифесты из этого репо. При окончании работы
кластер полностью удаляется (`terraform destroy`), state-файлы и манифесты
остаются в Git и здесь, на локальной машине.

## Стек

| Слой | Инструмент |
|------|-----------|
| Provisioning | Terraform + Yandex Cloud provider |
| GitOps | Flux v2 |
| CNI | Yandex Cloud CNI (встроен в Managed K8s) |
| Ingress | ingress-nginx (HelmRelease) |
| TLS | cert-manager + Let's Encrypt (HTTP-01) |
| Hostname | `<static-ip>.nip.io` (домен не нужен) |
| Secrets | SOPS + age |
| Images | GHCR (ghcr.io/sewaustav/...) |

## Структура

```
casego-gitops/
├── terraform/              # Cluster lifecycle
├── clusters/prod/          # Точка входа Flux
├── infrastructure/         # Ingress, cert-manager, SOPS
├── apps/                   # Сервисы CaseGo + БД
├── scripts/                # bootstrap.sh, teardown.sh
└── docs/                   # Phase-by-phase инструкции
```

## Жизненный цикл

```bash
# Поднять (≈ 5-7 минут)
./scripts/bootstrap.sh

# Удалить
./scripts/teardown.sh
```

## Фазы внедрения

- [x] **Фаза 0** — Структура репозитория (этот шаг)
- [ ] **[Фаза 1](docs/phase-1-prerequisites.md)** — Установка CLI и онбординг в Yandex Cloud
- [ ] **[Фаза 2](docs/phase-2-terraform.md)** — Terraform поднимает пустой кластер
- [ ] **[Фаза 3](docs/phase-3-flux.md)** — Flux + Ingress + cert-manager + SOPS
- [ ] **[Фаза 4](docs/phase-4-apps.md)** — Манифесты приложений CaseGo
