# VPC Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet
}

output "private_app_subnet_ids" {
  description = "Private app subnet IDs"
  value       = module.vpc.app_subnet
}

output "private_db_subnet_ids" {
  description = "Private DB subnet IDs"
  value       = module.vpc.db_subnet
}

# ===========================================
# ECS Outputs
# ===========================================

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs.cluster_name
}

output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = module.ecs.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value       = module.ecs.task_role_arn
}

# ===========================================
# ECR Outputs
# ===========================================

output "ecr_repositories" {
  description = "Map of all ECR repositories"
  value       = module.ecr.ecr_repositories
}

# ===========================================
# Security Groups Outputs
# ===========================================

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = module.security_groups.alb_sg_id
}

output "ecs_tasks_security_group_id" {
  description = "ECS Tasks Security Group ID"
  value       = module.security_groups.ecs_tasks_sg_id
}

# ===========================================
# ALB Outputs
# ===========================================

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "backend_target_group_arn" {
  description = "Backend Target Group ARN"
  value       = module.alb.backend_target_group_arn
}

output "frontend_target_group_arn" {
  description = "Frontend Target Group ARN"
  value       = module.alb.frontend_target_group_arn
}

# ===========================================
# RDS Outputs
# ===========================================

output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = var.create_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_instance_address" {
  description = "RDS instance address"
  value       = var.create_rds ? module.rds[0].db_instance_address : null
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = var.create_rds ? module.rds[0].db_instance_port : null
}

output "rds_database_name" {
  description = "Database name"
  value       = var.create_rds ? module.rds[0].db_name : null
}

output "rds_master_username" {
  description = "Master username"
  value       = var.create_rds ? module.rds[0].db_master_username : null
  sensitive   = true
}

# ===========================================
# CloudFront Outputs
# ===========================================

output "cloudfront_id" {
  description = "CloudFront Distribution ID"
  value       = var.create_cloudfront ? module.cloudfront[0].cloudfront_id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = var.create_cloudfront ? module.cloudfront[0].cloudfront_domain_name : null
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront Distribution Hosted Zone ID"
  value       = var.create_cloudfront ? module.cloudfront[0].cloudfront_hosted_zone_id : null
}

output "cloudfront_status" {
  description = "CloudFront Distribution Status"
  value       = var.create_cloudfront ? module.cloudfront[0].cloudfront_status : null
}

# ===========================================
# WAF Outputs
# ===========================================

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.create_waf ? module.waf[0].web_acl_id : null
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.create_waf ? module.waf[0].web_acl_arn : null
}

output "waf_web_acl_name" {
  description = "WAF Web ACL Name"
  value       = var.create_waf ? module.waf[0].web_acl_name : null
}

output "waf_web_acl_capacity" {
  description = "WAF Web ACL Capacity"
  value       = var.create_waf ? module.waf[0].web_acl_capacity : null
}
