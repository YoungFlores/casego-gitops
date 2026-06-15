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
  zone = var.zone
}

variable "folder_id" {
  type        = string
  description = "Yandex Cloud folder ID"
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "k8s_version" {
  type    = string
  default = "1.30"
}

resource "yandex_vpc_network" "casego" {
  name = "casego-net"
}

resource "yandex_vpc_subnet" "casego" {
  name           = "casego-subnet-a"
  zone           = var.zone
  network_id     = yandex_vpc_network.casego.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_iam_service_account" "k8s_cluster" {
  name = "casego-k8s-cluster"
}

resource "yandex_iam_service_account" "k8s_node" {
  name = "casego-k8s-node"
}

resource "yandex_resourcemanager_folder_iam_member" "cluster_editor" {
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

resource "yandex_kubernetes_cluster" "casego" {
  name        = "casego-prod"
  network_id  = yandex_vpc_network.casego.id
  description = "CaseGo production cluster (managed by Terraform)"

  master {
    version = var.k8s_version
    zonal {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.casego.id
    }
    public_ip = true
  }

  network_policy_provider = "CALICO"

  service_account_id      = yandex_iam_service_account.k8s_cluster.id
  node_service_account_id = yandex_iam_service_account.k8s_node.id

  release_channel = "STABLE"

  depends_on = [
    yandex_resourcemanager_folder_iam_member.cluster_editor,
    yandex_resourcemanager_folder_iam_member.vpc_admin,
  ]
}

resource "yandex_kubernetes_node_group" "casego_main" {
  cluster_id = yandex_kubernetes_cluster.casego.id
  name       = "casego-main"
  version    = var.k8s_version

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores  = 4
      memory = 8
    }
    boot_disk {
      type = "network-ssd"
      size = 64
    }
    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.casego.id]
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
}

output "cluster_id" {
  value = yandex_kubernetes_cluster.casego.id
}

output "external_endpoint" {
  value = yandex_kubernetes_cluster.casego.master[0].external_v4_endpoint
}
