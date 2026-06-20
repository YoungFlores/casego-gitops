terraform {
  required_version = ">= 1.5"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
}

provider "yandex" {
  zone      = var.zone
  folder_id = var.folder_id
}

variable "folder_id" {
  type        = string
  description = "Yandex Cloud folder ID (b1g1u5d8vostqd57krmb)"
}

variable "zone" {
  type    = string
  default = "ru-central1-d"
}

variable "k8s_version" {
  type    = string
  default = "1.33"
}

# ── Existing network (import if needed) ───────────────────────────────
# Network ID: enpcvqra91i8ds5bgs7f  name: default
# Subnet ID:  fl8q3e1t34h2vsn4bv13  name: default-ru-central1-d  CIDR: 10.130.0.0/24
#
# If re-creating from scratch uncomment these resources and remove data sources below.
#
# resource "yandex_vpc_network" "casego" {
#   name = "casego-net"
# }
# resource "yandex_vpc_subnet" "casego" {
#   name           = "casego-subnet-d"
#   zone           = var.zone
#   network_id     = yandex_vpc_network.casego.id
#   v4_cidr_blocks = ["10.130.0.0/24"]
# }

data "yandex_vpc_network" "casego" {
  network_id = "enpcvqra91i8ds5bgs7f"
}

data "yandex_vpc_subnet" "casego" {
  subnet_id = "fl8q3e1t34h2vsn4bv13"
}

# ── Service accounts ──────────────────────────────────────────────────
resource "yandex_iam_service_account" "k8s_cluster" {
  name = "k8s-cluster-awf"
}

resource "yandex_iam_service_account" "k8s_node" {
  name = "k8s-node-group-b1t"
}

resource "yandex_resourcemanager_folder_iam_member" "cluster_agent" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "node_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node.id}"
}

# ── Kubernetes cluster ────────────────────────────────────────────────
resource "yandex_kubernetes_cluster" "casego" {
  name       = "casego-cluster"
  network_id = data.yandex_vpc_network.casego.id

  master {
    version = var.k8s_version
    zonal {
      zone      = var.zone
      subnet_id = data.yandex_vpc_subnet.casego.id
    }
    public_ip = true

    maintenance_policy {
      auto_upgrade = true
    }
  }

  network_policy_provider = "CALICO"

  release_channel = "REGULAR"

  service_account_id      = yandex_iam_service_account.k8s_cluster.id
  node_service_account_id = yandex_iam_service_account.k8s_node.id

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.112.0.0/16"
    service_ipv4_cidr_block  = "10.96.0.0/16"
    node_ipv4_cidr_mask_size = 24
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.cluster_agent,
    yandex_resourcemanager_folder_iam_member.vpc_admin,
  ]
}

# ── Node group ────────────────────────────────────────────────────────
resource "yandex_kubernetes_node_group" "casego_nodes" {
  cluster_id = yandex_kubernetes_cluster.casego.id
  name       = "casego-nodes"
  version    = var.k8s_version

  instance_template {
    platform_id = "standard-v4a"

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 50
    }

    boot_disk {
      type = "network-hdd"
      size = 96
    }

    network_interface {
      nat        = true
      subnet_ids = [data.yandex_vpc_subnet.casego.id]
    }

    scheduling_policy {
      preemptible = true
    }

    container_runtime {
      type = "containerd"
    }

    metadata = {
      ssh-keys = "maks:${file("~/.ssh/id_ed25519.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }

  deploy_policy {
    max_expansion   = 3
    max_unavailable = 1
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }
}

# ── Outputs ───────────────────────────────────────────────────────────
output "cluster_id" {
  value = yandex_kubernetes_cluster.casego.id
}

output "external_endpoint" {
  value = yandex_kubernetes_cluster.casego.master[0].external_v4_endpoint
}
