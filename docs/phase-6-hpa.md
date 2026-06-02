# Фаза 6 — Автоскейлинг (HPA)

Цель: сервисы автоматически масштабируются по нагрузке CPU через
`HorizontalPodAutoscaler`.

## Метрики (metrics-server)

HPA по CPU требует metrics-server. На **Yandex Cloud Managed Kubernetes он уже
установлен платформой** (в `kube-system`, APIService `v1beta1.metrics.k8s.io`),
поэтому свой ставить **не нужно** — `kubectl top nodes` работает из коробки.

> Если поднимаешь это на кластере без metrics-server (kubeadm/k3s и т.п.) —
> поставь его отдельно (Helm chart `metrics-server` от kubernetes-sigs); на
> kubeadm-кластерах обычно нужен флаг `--kubelet-insecure-tls`.

## Что появилось

```
apps/<service>/
├── hpa.yaml                    # HorizontalPodAutoscaler (autoscaling/v2)
└── deployment.yaml             # из spec убран replicas — им управляет HPA
```

HPA добавлены на: `auth`, `payment`, `profile`, `caseprofile`, `casego`.
Параметры одинаковые: `minReplicas: 1`, `maxReplicas: 5`, цель — средняя
утилизация CPU 70%. Базы (postgres, redis) намеренно без HPA.

## Важные детали

- **`replicas` убран из деплойментов.** Иначе Flux на каждой реконсиляции (раз в
  10 мин) сбрасывал бы число подов обратно, конфликтуя с HPA. Без поля Deployment
  стартует с 1 реплики, дальше масштабом владеет HPA.
- **HPA по CPU требует `resources.requests.cpu`** — он уже прописан во всех
  сервисах, поэтому ничего добавлять не пришлось.

## Проверка

```bash
kubectl top pods -n casego-apps
kubectl get hpa -n casego-apps    # TARGETS показывает <x>%/70%, не <unknown>
```

Нагрузочный тест (число реплик должно вырасти):

```bash
kubectl -n casego-apps run load --rm -it --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://casego:8081/ >/dev/null; done"
kubectl get hpa -n casego-apps -w
```
