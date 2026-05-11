# Фаза 3 — Flux + Infrastructure

Цель: Flux синкается с `casego-gitops`, в кластере поднялись Ingress-NGINX и
cert-manager, по nip.io-хосту доступен default backend с валидным
Let's Encrypt-сертификатом.

## Что появится

```
clusters/prod/
├── flux-system/            # создаст flux bootstrap
├── infrastructure.yaml     # Kustomization → ../../infrastructure
└── apps.yaml               # Kustomization → ../../apps (пока пусто)

infrastructure/
├── sources/
│   ├── ingress-nginx.yaml  # HelmRepository
│   └── jetstack.yaml       # HelmRepository (cert-manager)
├── ingress-nginx/
│   ├── namespace.yaml
│   ├── release.yaml        # HelmRelease с service.loadBalancerIP=<static IP>
│   └── kustomization.yaml
├── cert-manager/
│   ├── namespace.yaml
│   ├── release.yaml        # HelmRelease (CRDs включены)
│   ├── cluster-issuer.yaml # Let's Encrypt prod
│   └── kustomization.yaml
└── sops-age/
    └── secret.enc.yaml     # age private key (SOPS не нужен — это сам ключ)
```

## Шаги

1. Сгенерировать age-ключ локально:
   ```bash
   age-keygen -o ~/.config/sops/age/casego.txt
   ```
   `~/.config/sops/age/casego.txt` содержит pubkey (закомменчена в файле) и
   privkey. Pubkey копируем в `.sops.yaml` (заменяя `REPLACE_WITH_AGE_PUBLIC_KEY`).

2. Bootstrap Flux:
   ```bash
   export GITHUB_TOKEN=<PAT из Фазы 1>
   export GITHUB_USER=<твой логин>

   flux bootstrap github \
     --owner=$GITHUB_USER \
     --repository=casego-gitops \
     --branch=main \
     --path=clusters/prod \
     --personal
   ```
   Эта команда:
   - проверит коннект к кластеру (kubectl)
   - создаст в репо папку `clusters/prod/flux-system/`
   - закоммитит и запушит Flux-манифесты
   - в кластере поднимет namespace `flux-system` с controllers

3. Залить age private key в кластер:
   ```bash
   cat ~/.config/sops/age/casego.txt | \
     kubectl -n flux-system create secret generic sops-age \
     --from-file=age.agekey=/dev/stdin
   ```

4. Закоммитить `infrastructure/*` манифесты в репо — Flux подхватит и поднимет
   Ingress-NGINX + cert-manager.

## Проверка

```bash
flux get kustomizations
kubectl -n ingress-nginx get svc        # EXTERNAL-IP == static IP из Terraform
kubectl get clusterissuer               # letsencrypt-prod Ready=True
```

После этого → Фаза 4.
