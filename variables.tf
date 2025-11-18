# ===========================================
# Project Configuration
# ===========================================

variable "project_name" {
  description = "프로젝트 이름 (리소스 접두사)"
  type        = string
  default     = "cat"
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ===========================================
# VPC Configuration
# ===========================================

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.180.0.0/20"
}

variable "availability_zones" {
  description = "사용할 가용 영역 리스트"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 리스트"
  type        = list(string)
  default     = ["10.180.0.0/24", "10.180.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private App 서브넷 CIDR 리스트"
  type        = list(string)
  default     = ["10.180.4.0/22", "10.180.8.0/22"]
}

variable "private_db_subnet_cidrs" {
  description = "Private DB 서브넷 CIDR 리스트"
  type        = list(string)
  default     = ["10.180.2.0/24", "10.180.3.0/24"]
}

# ===========================================
# ECS Configuration
# ===========================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS"
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch log retention for ECS (days)"
  type        = number
  default     = 7
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot for cost optimization"
  type        = bool
  default     = true
}

# ===========================================
# RDS Configuration
# ===========================================

variable "create_rds" {
  description = "Whether to create RDS instance"
  type        = bool
  default     = false
}

variable "rds_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.39"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_database_name" {
  description = "Name of the default database"
  type        = string
  default     = "catdb"
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
}

variable "rds_master_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
  default     = ""
}

# ===========================================
# ALB Configuration
# ===========================================

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener (optional)"
  type        = string
  default     = ""
}

variable "backend_domain" {
  description = "Domain for backend API"
  type        = string
  default     = "cicd-api.go-to-learn.net"
}

variable "frontend_domain" {
  description = "Domain for frontend"
  type        = string
  default     = "cicd.go-to-learn.net"
}
