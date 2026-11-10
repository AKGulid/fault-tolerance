resource "yandex_vpc_subnet" "subnet" {
  name           = "hw-subnet"
  zone           = var.yc_zone
  network_id     = "enppssoq3lml3aknbg3v"
  v4_cidr_blocks = ["10.10.0.0/24"]
}

# --- Две идентичные ВМ через count ---
resource "yandex_compute_instance" "web" {
  count       = var.vm_count
  name        = "web-vm-${count.index + 1}"   # web-vm-1, web-vm-2
  platform_id = "standard-v3"
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      # Актуальный образ Ubuntu 22.04 LTS подтягиваем через data source
      image_id = data.yandex_compute_image.ubuntu2204.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true   # публичный IP для доступа в интернет
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      ssh_public_key = file("~/.ssh/id_ed25519.pub")
    })
  }
}

# --- Data source для актуального образа Ubuntu 22.04 ---
data "yandex_compute_image" "ubuntu2204" {
  family    = "ubuntu-2204-lts"
  folder_id = "standard-images"
}

# --- Целевая группа: динамически добавляем обе ВМ ---
resource "yandex_lb_target_group" "web_tg" {
  name      = "web-target-group"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = yandex_vpc_subnet.subnet.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# --- Сетевой балансировщик нагрузки ---
resource "yandex_lb_network_load_balancer" "web_nlb" {
  name = "web-network-balancer"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_tg.id
    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}