# locals {
#   network_interface = google_compute_instance.instance.network_interface[0]
#   instance_nat_ip   = length(local.network_interface.access_config) > 0 ? local.network_interface.access_config[0].nat_ip : null
#   instance_ip       = coalesce(local.instance_nat_ip, local.network_interface.network_ip)
# }

# output "site_url" {
#   description = "Site Url"
#   value       = "https://${local.instance_ip}/studio/"
# }

output "external_ips" {
  description = "A list of external IP addresses for the Norsk Gateway instances."
  value = [
    for ni in flatten(module.norsk_gw.network_interfaces) : one(ni.access_config).nat_ip
    if length(ni.access_config) > 0
  ]
}

output "admin_user" {
  description = "Norsk admin username."
  value       = module.norsk_gw.admin_user
}

output "admin_password" {
  description = "Norsk admin password."
  value       = module.norsk_gw.admin_password
  sensitive   = true
}

# output "instance_self_link" {
#   description = "Self-link for the compute instance."
#   value       = google_compute_instance.instance.self_link
# }

# output "instance_zone" {
#   description = "Zone for the compute instance."
#   value       = var.zone
# }

# output "instance_machine_type" {
#   description = "Machine type for the compute instance."
#   value       = var.machine_type
# }

# output "instance_nat_ip" {
#   description = "External IP of the compute instance."
#   value       = local.instance_nat_ip
# }

# output "instance_network" {
#   description = "Self-link for the network of the compute instance."
#   value       = var.networks[0]
# }
