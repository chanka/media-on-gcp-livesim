locals {
  network_interfaces = [for i, n in var.networks : {
    network     = n,
    subnetwork  = length(var.sub_networks) > i ? element(var.sub_networks, i) : null
    external_ip = length(var.external_ips) > i ? element(var.external_ips, i) : "NONE"
    }
  ]

  project = {
    id     = var.project_id
    name   = data.google_project.project.name
    number = data.google_project.project.number
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

module "norsk_gw" {
  source = "./norsk-gw/stable"

  project_id = local.project.id
  region     = var.region
  zone       = var.zone
  instance_count = var.instance_count

  networks = [module.vpc.network_name]
}


### OLD BELOW THIS ###

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
# resource "google_compute_instance" "instance" {
#   name         = "${var.goog_cm_deployment_name}-vm"
#   machine_type = var.machine_type
#   zone         = var.zone

#   tags = ["${var.goog_cm_deployment_name}-deployment"]

#   boot_disk {
#     device_name = "autogen-vm-tmpl-boot-disk"

#     initialize_params {
#       size  = var.boot_disk_size
#       type  = var.boot_disk_type
#       image = var.source_image
#     }
#   }

#   can_ip_forward = var.ip_forward

#   shielded_instance_config {
#     enable_secure_boot          = true
#     enable_integrity_monitoring = true
#   }

#   metadata = merge(local.metadata, {

#     # Updated startup-script to use the key
#     startup-script = <<-EOT
#       #!/bin/bash
#       set -e # Exit immediately if a command exits with a non-zero status.
#       echo ">>> Starting startup script..."
#       gsutil cp gs://ghacks-media-on-gcp-private-temp/license.json /var/norsk-studio/norsk-studio-docker/secrets/license.json
#       mkdir -p /var/norsk-studio/norsk-studio-docker/data/media
#       gcloud storage rsync gs://ghacks-media-on-gcp-public-temp/media /var/norsk-studio/norsk-studio-docker/data/media
#       echo ">>> Startup script finished."
#     EOT
#   })

#   dynamic "network_interface" {
#     for_each = local.network_interfaces
#     content {
#       network    = network_interface.value.network
#       subnetwork = network_interface.value.subnetwork

#       dynamic "access_config" {
#         for_each = network_interface.value.external_ip == "NONE" ? [] : [1]
#         content {
#           nat_ip = network_interface.value.external_ip == "EPHEMERAL" ? null : network_interface.value.external_ip
#         }
#       }
#     }
#   }

#   guest_accelerator {
#     type  = var.accelerator_type
#     count = var.accelerator_count
#   }

#   scheduling {
#     // GPUs do not support live migration
#     on_host_maintenance = var.accelerator_count > 0 ? "TERMINATE" : "MIGRATE"
#   }

#   service_account {
#     email = "default"
#     scopes = compact([
#       "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
#       "https://www.googleapis.com/auth/devstorage.read_only",
#       "https://www.googleapis.com/auth/logging.write",
#       "https://www.googleapis.com/auth/monitoring.write"
#     ])
#   }
# }

# resource "random_password" "admin" {
#   length  = 22
#   special = false
# }
