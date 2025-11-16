# ===========================================
# ECS Cluster Variables
# ===========================================

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "cat-cluster"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot for cost optimization"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
