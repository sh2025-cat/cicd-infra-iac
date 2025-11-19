# ===========================================
# ALB Variables
# ===========================================

variable "name_prefix" {
  description = "Prefix for ALB resources"
  type        = string
  default     = "cat"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "backend_domain" {
  description = "Domain for backend API"
  type        = string
}

variable "frontend_domain" {
  description = "Domain for frontend"
  type        = string
}

variable "backend_port" {
  description = "Port for backend target group"
  type        = number
  default     = 80
}

variable "frontend_port" {
  description = "Port for frontend target group"
  type        = number
  default     = 80
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
