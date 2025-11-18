# ===========================================
# CloudWatch Logs Variables
# ===========================================

variable "name_prefix" {
  description = "Prefix for log group names"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
