# -----------------------------------------------------------------------------
# main.tf - Main infrastructure resources
# -----------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  # This applies to all resources that take labels, e.g. instance
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#default_labels-1
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#labels-1
  default_labels = {
  }
}

locals {
  # Derive the region from the zone variable (e.g., "europe-west4" from "europe-west4-a")
  region = join("-", slice(split("-", var.zone), 0, 2))

  metadata = {
    norsk-studio-admin-password = random_password.admin.result
    deploy_domain_name          = var.domain_name
    deploy_certbot_email        = var.certbot_email
    google-logging-enable       = "0"
    google-monitoring-enable    = "0"
  }
}

# Reserve a static external IP address for each instance
resource "google_compute_address" "static_ip" {
  for_each = var.instances
  name     = "${each.key}-static-ip"
  region   = local.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "instance" {
  for_each = var.instances

  name         = "${each.key}-vm"
  machine_type = each.value.machine_type
  zone         = var.zone

  tags = ["norsk-livesim-deployment"]

  boot_disk {
    device_name = "autogen-vm-tmpl-boot-disk"

    initialize_params {
      size  = var.boot_disk_size
      type  = each.value.boot_disk_type
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
    # startup-script = <<-EOT
    #   #!/bin/bash
    #   set -e # Exit immediately if a command exits with a non-zero status.
    #   echo ">>> Starting startup script..."
    #   gsutil cp gs://ghacks-media-on-gcp-private-temp/license.json /var/norsk-studio/norsk-studio-docker/secrets/license.json
    #   echo ">>> Startup script finished."
    # EOT
  })

  network_interface {
    network    = var.networks[0]
    subnetwork = length(var.sub_networks) > 0 ? var.sub_networks[0] : null

    access_config {
      // Assign the static IP address reserved for this specific instance
      nat_ip = google_compute_address.static_ip[each.key].address
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

  name    = "norsk-livesim-tcp-80"
  network = element(var.networks, 0)

  allow {
    ports    = ["80"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_80_source_ranges) : trimspace(range)])

  target_tags = ["norsk-livesim-deployment"]
}

resource "google_compute_firewall" "tcp_443" {
  count = var.enable_tcp_443 ? 1 : 0

  name    = "norsk-livesim-tcp-443"
  network = element(var.networks, 0)

  allow {
    ports    = ["443"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_443_source_ranges) : trimspace(range)])

  target_tags = ["norsk-livesim-deployment"]
}

resource "google_compute_firewall" "tcp_3478" {
  count = var.enable_tcp_3478 ? 1 : 0

  name    = "norsk-livesim-tcp-3478"
  network = element(var.networks, 0)

  allow {
    ports    = ["3478"]
    protocol = "tcp"
  }

  source_ranges = compact([for range in split(",", var.tcp_3478_source_ranges) : trimspace(range)])

  target_tags = ["norsk-livesim-deployment"]
}

resource "google_compute_firewall" "udp_3478" {
  count = var.enable_udp_3478 ? 1 : 0

  name    = "norsk-livesim-udp-3478"
  network = element(var.networks, 0)

  allow {
    ports    = ["3478"]
    protocol = "udp"
  }

  source_ranges = compact([for range in split(",", var.udp_3478_source_ranges) : trimspace(range)])

  target_tags = ["norsk-livesim-deployment"]
}

resource "google_compute_firewall" "udp_5001" {
  count = var.enable_udp_5001 ? 1 : 0

  name    = "norsk-livesim-udp-5001-5200"
  network = element(var.networks, 0)

  allow {
    ports    = ["5001-5200"]
    protocol = "udp"
  }

  source_ranges = compact([for range in split(",", var.udp_5001_source_ranges) : trimspace(range)])

  target_tags = ["norsk-livesim-deployment"]
}

resource "random_password" "admin" {
  length  = 22
  special = false
}

# -----------------------------------------------------------------------------
# variables.tf - Input variables for the module
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "explore-media-on-gcp-livesim"
}

// Map of instances to create, defining the name and machine type for each.
variable "instances" {
  description = "A map of compute instances to create, specifying the machine type for each."
  type = map(object({
    machine_type   = string
    boot_disk_type = string
  }))
  default = {
    "livesim-01" = {
      machine_type   = "c4d-standard-16-lssd"
      boot_disk_type = "hyperdisk-balanced"
    },
    "livesim-02" = {
      machine_type   = "c4d-standard-16-lssd"
      boot_disk_type = "hyperdisk-balanced"
    },
    "fecamgw-01" = {
      machine_type   = "c4d-highcpu-8"
      boot_disk_type = "hyperdisk-balanced"
    },
    "fecamgw-02" = {
      machine_type   = "c4d-highcpu-8"
      boot_disk_type = "hyperdisk-balanced"
    },
    "fecamgw-03" = {
      machine_type   = "c4d-highcpu-8"
      boot_disk_type = "hyperdisk-balanced"
    },
    "fecamgw-04" = {
      machine_type   = "c4d-highcpu-8"
      boot_disk_type = "hyperdisk-balanced"
    }
  }
}

variable "source_image" {
  description = "The image name for the disk for the VM instance."
  type        = string
  default     = "projects/explore-media-on-gcp-livesim/global/images/norsk-image-ibc-alpha-debian-12-x86-64-2025-08-29"
}

variable "zone" {
  description = "The zone for the solution to be deployed."
  type        = string
  default     = "europe-west4-a"
}

variable "boot_disk_size" {
  description = "The boot disk size for the VM instance in GBs"
  type        = number
  default     = 50
}

variable "networks" {
  description = "The network name to attach the VM instance."
  type        = list(string)
  default     = ["default"]
}

variable "sub_networks" {
  description = "The sub network name to attach the VM instance."
  type        = list(string)
  default     = []
}

variable "ip_forward" {
  description = "Whether to allow sending and receiving of packets with non-matching source or destination IPs. (Not recommended.)"
  type        = bool
  default     = false
}

variable "enable_tcp_80" {
  description = "Allow HTTP traffic from the Internet (optional, redirects to HTTPS)"
  type        = bool
  default     = true
}

variable "tcp_80_source_ranges" {
  description = "Source IP ranges for HTTP traffic"
  type        = string
  default     = ""
}

variable "enable_tcp_443" {
  description = "Allow HTTPS traffic from the Internet"
  type        = bool
  default     = true
}

variable "tcp_443_source_ranges" {
  description = "Source IP ranges for HTTPS traffic"
  type        = string
  default     = ""
}

variable "enable_tcp_3478" {
  description = "Allow TCP port 3478 (STUN/TURN) traffic from the Internet"
  type        = bool
  default     = true
}

variable "tcp_3478_source_ranges" {
  description = "Source IP ranges for TCP port 3478 traffic"
  type        = string
  default     = ""
}

variable "enable_udp_3478" {
  description = "Allow UDP port 3478 (STUN/TURN) traffic from the Internet"
  type        = bool
  default     = true
}

variable "udp_3478_source_ranges" {
  description = "Source IP ranges for UDP port 3478 traffic"
  type        = string
  default     = ""
}

variable "enable_udp_5001" {
  description = "Allow UDP port 5001-5200 traffic (example SRT port) from the Internet"
  type        = bool
  default     = true
}

variable "udp_5001_source_ranges" {
  description = "Source IP ranges for UDP port 5001-5200 traffic"
  type        = string
  default     = ""
}

variable "accelerator_type" {
  description = "The accelerator type resource exposed to this instance. E.g. nvidia-tesla-p100."
  type        = string
  default     = "nvidia-tesla-p100"
}

variable "accelerator_count" {
  description = "The number of the guest accelerator cards exposed to this instance."
  type        = number
  default     = 0
}

variable "domain_name" {
  description = "The domain name that you will access this Norsk Studio deployment through, which you must set up through your DNS provider to point to the VM instance."
  type        = string
  default     = ""
}

variable "certbot_email" {
  description = "The email where you will receive HTTPS certificate expiration notices from Let's Encrypt."
  type        = string
  default     = "chanka-norsk@google.com"
}


# -----------------------------------------------------------------------------
# outputs.tf - Outputs for the module
# -----------------------------------------------------------------------------

output "site_urls" {
  description = "Site Urls for each instance"
  value       = { for k, inst in google_compute_instance.instance : k => "https://${coalesce(try(inst.network_interface[0].access_config[0].nat_ip, null), inst.network_interface[0].network_ip)}/studio/" }
}

output "admin_user" {
  description = "Username for Admin password."
  value       = "norsk-studio-admin"
}

output "admin_password" {
  description = "Password for Admin."
  value       = random_password.admin.result
  sensitive   = true
}

output "instance_self_links" {
  description = "A map of self-links for the compute instances."
  value       = { for k, inst in google_compute_instance.instance : k => inst.self_link }
}

output "instance_zones" {
  description = "A map of zones for the compute instances."
  value       = { for k, inst in google_compute_instance.instance : k => inst.zone }
}

output "instance_machine_types" {
  description = "A map of machine types for the compute instances."
  value       = { for k, inst in google_compute_instance.instance : k => inst.machine_type }
}

output "instance_nat_ips" {
  description = "A map of external IPs for the compute instances."
  value       = { for k, inst in google_compute_instance.instance : k => try(inst.network_interface[0].access_config[0].nat_ip, "N/A") }
}

output "instance_networks" {
  description = "A map of self-links for the network of the compute instances."
  value       = { for k, inst in google_compute_instance.instance : k => inst.network_interface[0].network }
}
