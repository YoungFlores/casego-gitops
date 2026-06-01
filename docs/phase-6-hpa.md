# Фаза 6 — Автоскейлинг (metrics-server + HPA)

Цель: сервисы автоматически масштабируются по нагрузке CPU. Для этого в кластере
работает `metrics-server` (источник метрик), а на каждый сервис навешан
`HorizontalPodAutoscaler`.

## Что появилось

```
infrastructure/
├── sources/
│   └── metrics-server.yaml     # HelmRepository (kubernetes-sigs)
└── metrics-server/
    ├── release.yaml            # HelmRelease в kube-system (chart 3.13.0)
    └── kustomization.yaml

apps/<service>/
├── hpa.yaml                    # HorizontalPodAutoscaler (autoscaling/v2)
└── deployment.yaml             # из spec убран replicas — им управляет HPA
```

HPA добавлены на: `auth`, `payment`, `profile`, `caseprofile`, `casego`.
Параметры одинаковые: `minReplicas: 1`, `maxReplicas: 5`, цель — средняя
утилизация CPU 70%. Базы (postgres, redis) намеренно без HPA.

## Важные детали

- **`replicas` убран из деплойментов.** Иначе Flux на каждой реконсиляции (раз в
  10 мин) сбрасывал бы число подов обратно к указанному значению, конфликтуя с
  HPA. Без поля Deployment стартует с 1 репликой, дальше масштабом владеет HPA.
- **HPA по CPU требует `resources.requests.cpu`** — он уже прописан во всех
  сервисах, поэтому ничего добавлять не пришлось.
- **`--kubelet-insecure-tls`** в `metrics-server/release.yaml`. На кластерах с
  self-signed kubelet serving-сертификатами (типичный kubeadm/Terraform-кластер)
  без этого флага metrics-server не скрейпит kubelet (x509). Если у kubelet
  валидные сертификаты — флаг можно убрать.

## Проверка

```bash
flux reconcile kustomization infrastructure --with-source
flux reconcile kustomization apps --with-source

kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes                 # метрики приходят
kubectl top pods -n casego-apps

kubectl get hpa -n casego-apps    # TARGETS показывает <x>%/70%, не <unknown>
```

Нагрузочный тест (число реплик должно вырасти):

```bash
kubectl -n casego-apps run load --rm -it --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://casego:8081/ >/dev/null; done"
kubectl get hpa -n casego-apps -w
```
