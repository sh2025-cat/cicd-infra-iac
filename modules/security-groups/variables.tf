# ===========================================
# Security Groups Variables
# ===========================================

variable "name_prefix" {
  description = "Prefix for security group names"
  type        = string
  default     = "cat"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "create_rds_sg" {
  description = "Whether to create RDS security group"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
