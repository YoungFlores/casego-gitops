# Фаза 2 — Подключение kubectl к существующему кластеру

> **Изменение плана:** изначально кластер создавался через Terraform. Сейчас
> `casego-cluster` создан вручную через консоль YC, поэтому Terraform пропускаем
> и сразу подключаемся. Жизненный цикл «создал/удалил» — через консоль или yc CLI.

## Шаг 1. Получить kubeconfig

```bash
yc managed-kubernetes cluster get-credentials \
  --name casego-cluster \
  --external \
  --force
```

Команда:
- получает endpoint API-сервера через публичный IP
- добавляет контекст `yc-casego-cluster` в `~/.kube/config`
- ставит этот контекст активным
- `--force` перезаписывает запись если она уже есть

Флаг `--external` критичен — без него попытается коннектиться через
внутренний VPC-адрес, а у тебя локального VPN в YC нет.

## Шаг 2. Проверить подключение

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -A
```

Должно показать ноды кластера в статусе `Ready` и системные поды
(coredns, ip-masq-agent, kube-proxy, и т.д.).

## Шаг 3. Зафиксировать параметры

Запиши себе (понадобятся в Фазе 4 для Ingress хостнеймов):

```bash
# IP master'a (для информации, не используется в манифестах)
yc managed-kubernetes cluster get casego-cluster --format json | \
  jq -r .master.endpoints.external_v4_endpoint

# Cluster ID
yc managed-kubernetes cluster get --name casego-cluster --format json | jq -r .id

# Folder / Cloud — должны совпадать с yc config list
yc config list
```

## Что делать когда захочешь сэкономить

Удалить кластер можно командой:
```bash
yc managed-kubernetes cluster delete --name casego-cluster
```

Создать обратно — либо через консоль с теми же параметрами, либо командой
`yc managed-kubernetes cluster create ...` с теми же флагами что использовал
изначально. **Важно**: после пересоздания static external IP для Ingress
LoadBalancer **может измениться**, потому что Service создаётся заново.
Зарезервируй static IP отдельно в Фазе 3 — это решит проблему.

После Шага 2 (kubectl видит ноды) → Фаза 3.
