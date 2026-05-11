# Фаза 2 — Terraform: пустой кластер встаёт

Цель: за одну команду `terraform apply` получить работающий K8s-кластер в YC,
выводы которого включают:

- public endpoint API-сервера
- static external IP для будущего LoadBalancer
- готовую команду `kubectl config ...` для подключения

## Что будет создано

| Ресурс | Что |
|--------|-----|
| `yandex_vpc_network.casego` | Сеть |
| `yandex_vpc_subnet.casego` | Подсеть в одной зоне |
| `yandex_vpc_address.lb` | Зарезервированный static IP для Ingress LoadBalancer |
| `yandex_kubernetes_cluster.casego` | Zonal K8s cluster (1 master) |
| `yandex_kubernetes_node_group.workers` | 2 ноды по 2 CPU / 4 GB |
| Сервис-аккаунты | SA для кластера и node group |

## Файлы

Все файлы появятся в `terraform/` на этой фазе. Сейчас они ещё не написаны —
напишу, когда подтвердишь, что Фаза 1 закончена.

- `versions.tf` — required_providers, version constraints
- `variables.tf` — cloud_id, folder_id, zone, cluster_name, k8s_version, и т.д.
- `main.tf` — все ресурсы
- `outputs.tf` — endpoint, static_ip, kubeconfig команда
- `terraform.tfvars.example` — пример заполнения

## Команды

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# отредактировать terraform.tfvars: подставить cloud_id, folder_id, путь к SA key

terraform init
terraform plan
terraform apply

# Получить kubeconfig
yc managed-kubernetes cluster get-credentials \
  --name casego --external --force

kubectl get nodes
```

После проверки `kubectl get nodes` → Фаза 3.
