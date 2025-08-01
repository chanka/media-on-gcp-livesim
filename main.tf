provider "google" {
  project = var.project_id
  # This applies to all resources that take labels, e.g. instance
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#default_labels-1
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#labels-1
  default_labels = {
  }
}

locals {
  network_interfaces = [for i, n in var.networks : {
    network     = n,
    subnetwork  = length(var.sub_networks) > i ? element(var.sub_networks, i) : null
    external_ip = length(var.external_ips) > i ? element(var.external_ips, i) : "NONE"
    }
  ]

  metadata = {
    norsk-studio-admin-password = random_password.admin.result
    deploy_domain_name          = var.domain_name
    deploy_certbot_email        = var.certbot_email
    google-logging-enable       = "0"
    google-monitoring-enable    = "0"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "instance" {
  name         = "${var.goog_cm_deployment_name}-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.goog_cm_deployment_name}-deployment"]

  boot_disk {
    device_name = "autogen-vm-tmpl-boot-disk"

    initialize_params {
      size  = var.boot_disk_size
      type  = var.boot_disk_type
      image = var.source_image
    }
  }

  can_ip_forward = var.ip_forward

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
  }

  metadata = merge(local.metadata, {

    # Updated startup-script to use the key
    startup-script = <<-EOT
      #!/bin/bash
      set -e # Exit immediately if a command exits with a non-zero status.
      echo ">>> Starting startup script..."
      gsutil cp gs://ghacks-media-on-gcp-private-temp/license.json /var/norsk-studio/norsk-studio-docker/secrets/license.json
      mkdir -p /var/norsk-studio/norsk-studio-docker/data/media
      gcloud storage rsync gs://ghacks-media-on-gcp-public-temp/media /var/norsk-studio/norsk-studio-docker/data/media
      echo ">>> Startup script finished."
    EOT
  })

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = network_interface.value.external_ip == "NONE" ? [] : [1]
        content {
          nat_ip = network_interface.value.external_ip == "EPHEMERAL" ? null : network_interface.value.external_ip
        }
      }
    }
  }

  guest_accelerator {
    type  = var.accelerator_type
    count = var.accelerator_count
  }

  scheduling {
    // GPUs do not support live migration
    on_host_maintenance = var.accelerator_count > 0 ? "TERMINATE" : "MIGRATE"
  }

  service_account {
    email = "default"
    scopes = compact([
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ])
  }
}

resource "google_compute_firewall" "tcp_80" {
  count = var.enable_tcp_80 ? 1 : 0

  name    = "${var.goog_cm_deployment_name}-tcp-80"
  network = element(var.networks, 0)

  allow {
    ports    = ["80"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_80_source_ranges) : trimspace(range)])

  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
}

resource "google_compute_firewall" "tcp_443" {
  count = var.enable_tcp_443 ? 1 : 0

  name    = "${var.goog_cm_deployment_name}-tcp-443"
  network = element(var.networks, 0)

  allow {
    ports    = ["443"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_443_source_ranges) : trimspace(range)])

  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
}

resource "google_compute_firewall" "tcp_3478" {
  count = var.enable_tcp_3478 ? 1 : 0

  name    = "${var.goog_cm_deployment_name}-tcp-3478"
  network = element(var.networks, 0)

  allow {
    ports    = ["3478"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_3478_source_ranges) : trimspace(range)])

  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
}

resource "google_compute_firewall" "udp_3478" {
  count = var.enable_udp_3478 ? 1 : 0

  name    = "${var.goog_cm_deployment_name}-udp-3478"
  network = element(var.networks, 0)

  allow {
    ports    = ["3478"]
    protocol = "udp"
  }

  source_ranges = compact([for range in split(",", var.udp_3478_source_ranges) : trimspace(range)])

  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
}

resource "google_compute_firewall" "udp_5001" {
  count = var.enable_udp_5001 ? 1 : 0

  name    = "${var.goog_cm_deployment_name}-udp-5001"
  network = element(var.networks, 0)

  allow {
    ports    = ["5001-5200"]
    protocol = "udp"
  }

  source_ranges = compact([for range in split(",", var.udp_5001_source_ranges) : trimspace(range)])

  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
}

resource "random_password" "admin" {
  length  = 22
  special = false
}
