variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "ibc-september"
}

// Marketplace requires this variable name to be declared
variable "goog_cm_deployment_name" {
  description = "The name of the deployment and VM instance."
  type        = string
  default     = "ibc-ghack-norsk-streams"
}

variable "source_image" {
  description = "The image name for the disk for the VM instance."
  type        = string
  default     = "projects/id3as-public/global/images/norsk-studio-byol-debian-12-x86-64-2025-07-29"
}

variable "zone" {
  description = "The zone for the solution to be deployed."
  type        = string
  default     = "europe-west4-a"
}

variable "machine_type" {
  description = "The machine type to create, e.g. e2-small"
  type        = string
  default     = "n2d-standard-8"
}

variable "boot_disk_type" {
  description = "The boot disk type for the VM instance."
  type        = string
  default     = "pd-balanced"
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

variable "external_ips" {
  description = "The external IPs assigned to the VM for public access."
  type        = list(string)
  default     = ["EPHEMERAL"]
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
