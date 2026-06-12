# Фаза 7 — Мониторинг (kube-prometheus-stack)

Цель: Prometheus + Grafana с готовыми дашбордами по кластеру и HTTP-метриками
сервисов через ingress-nginx. Стек урезан под маленькие ноды.

## Что появилось

```
infrastructure/
├── sources/
│   └── prometheus-community.yaml   # HelmRepository
└── monitoring/
    ├── namespace.yaml              # ns monitoring
    ├── release.yaml                # HelmRelease kube-prometheus-stack (86.2.2)
    ├── secrets/grafana-admin.yaml  # SOPS: логин/пароль Grafana
    └── kustomization.yaml
```

Плюс: в `ingress-nginx/release.yaml` включены метрики контроллера
(`controller.metrics.enabled`), а ServiceMonitor для них создаёт сам
prometheus-stack (`additionalServiceMonitors`) — так нет гонки за CRD.
В `clusters/prod/infrastructure.yaml` добавлена SOPS-декрипция (секрет Grafana
лежит в infrastructure, раньше декрипция была только у apps).

## Что урезано и почему

- **Alertmanager выключен** — алертить некуда, демо-кластер.
- **Persistence выключен** — графики живут, пока жив под; retention 6h.
- **Control-plane таргеты выключены** (kube-scheduler/controller-manager/etcd/
  kube-proxy) — в Managed K8s они недоступны, висели бы красными.
- Лимиты прижаты: Prometheus 512Mi/1Gi, Grafana 128/300Mi, экспортеры по мелочи.

## Доступ к Grafana

- URL: <https://grafana.158-160-192-124.nip.io> (ingress + Let's Encrypt)
- Логин: `admin`, пароль:
  ```bash
  sops -d infrastructure/monitoring/secrets/grafana-admin.yaml | grep admin-password
  ```

## Проверка

```bash
kubectl -n monitoring get pods          # prometheus, grafana, operator, ksm, node-exporter x2
kubectl get ingress -n monitoring       # grafana.<ip>.nip.io
```

В Grafana из коробки: дашборды «Kubernetes / Compute Resources / *» (ноды,
поды, неймспейсы). Для ingress-метрик импортнуть дашборд **9614**
(NGINX Ingress controller) через Dashboards → Import.

## Демо для защиты

1. Открыть дашборд Compute Resources / Namespace (Pods) для `casego-apps`.
2. Дать нагрузку:
   ```bash
   kubectl -n casego-apps run load --rm -it --image=busybox --restart=Never -- \
     /bin/sh -c "while true; do wget -q -O- http://casego:8081/ >/dev/null; done"
   ```
3. Смотреть: CPU растёт → HPA добавляет реплики (`kubectl get hpa -n casego-apps -w`)
   → на графике появляются новые поды. История «зачем Kubernetes» на одном экране.
