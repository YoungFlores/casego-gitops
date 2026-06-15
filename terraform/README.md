# Terraform: Yandex Cloud K8s cluster for CaseGo

Provisions the managed Kubernetes cluster the gitops repo deploys into.

## Usage

```sh
export YC_TOKEN=$(yc iam create-token)
export TF_VAR_folder_id=$(yc config get folder-id)

terraform init
terraform plan
terraform apply
```

## What it creates

- VPC network + one subnet in `ru-central1-a` (10.10.0.0/24)
- Two service accounts: cluster agent + node puller (for ghcr.io / cr.yandex)
- Zonal Kubernetes cluster, k8s 1.30, STABLE release channel, Calico network policy provider (required for NetworkPolicy enforcement)
- One node group, 2x `standard-v3` (4 vCPU, 8 GiB, 64 GiB SSD), with NAT for egress

## After apply

```sh
yc managed-kubernetes cluster get-credentials --external --name casego-prod
flux bootstrap github --owner=YoungFlores --repository=casego-gitops --branch=main --path=clusters/prod
```

The cluster is intentionally small (single zone, 2 nodes) — sufficient for the thesis demo. For production HA: switch master to `regional` block, raise node group count, add second node group across zones.
