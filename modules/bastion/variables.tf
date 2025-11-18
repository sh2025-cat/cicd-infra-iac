# ===========================================
# Bastion Host Variables
# ===========================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Bastion Host"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for Bastion Host"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 8
}

variable "allocate_eip" {
  description = "Whether to allocate Elastic IP for Bastion"
  type        = bool
  default     = true
}

variable "private_key_path" {
  description = "Path to save the private key"
  type        = string
  default     = "./ssh-keys"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
