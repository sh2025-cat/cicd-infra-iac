variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database host endpoint"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "recovery_window_in_days" {
  description = "Number of days that AWS Secrets Manager waits before deleting a secret"
  type        = number
  default     = 0 # Immediate deletion for dev, use 7-30 for production
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
