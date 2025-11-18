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

# ===========================================
# CloudFront Configuration
# ===========================================

variable "create_cloudfront" {
  description = "Create CloudFront distribution"
  type        = bool
  default     = false
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
  default     = ""
}

# ===========================================
# WAF Configuration
# ===========================================

variable "create_waf" {
  description = "Create WAF Web ACL for CloudFront"
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "Maximum number of requests per 5 minutes from a single IP"
  type        = number
  default     = 2000
}

variable "waf_enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics for WAF"
  type        = bool
  default     = false
}

variable "waf_enable_sampled_requests" {
  description = "Enable sampling of requests for WAF"
  type        = bool
  default     = false
}

# ===========================================
# Bastion Host Configuration
# ===========================================

variable "create_bastion" {
  description = "Whether to create Bastion Host"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allocate_eip" {
  description = "Whether to allocate Elastic IP for Bastion"
  type        = bool
  default     = true
}

variable "bastion_private_key_path" {
  description = "Path to save the Bastion private key"
  type        = string
  default     = "./ssh-keys"
}

variable "bastion_root_volume_size" {
  description = "Root volume size for Bastion (GB)"
  type        = number
  default     = 8
}

variable "bastion_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into Bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
