# ===========================================
# VPC Module
# ===========================================

module "vpc" {
  source = "./modules/vpc"

  name              = var.project_name
  vpc_cidr          = var.vpc_cidr
  azs               = var.availability_zones
  public_cidrs      = var.public_subnet_cidrs
  private_app_cidrs = var.private_app_subnet_cidrs
  private_db_cidrs  = var.private_db_subnet_cidrs
}

# ===========================================
# Security Groups Module
# ===========================================

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix                 = var.project_name
  vpc_id                      = module.vpc.vpc_id
  create_rds_sg               = var.create_rds
  create_bastion_sg           = var.create_bastion
  bastion_allowed_cidr_blocks = var.bastion_allowed_cidr_blocks

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# ECS Cluster Module
# ===========================================

module "ecs" {
  source = "./modules/ecs"

  cluster_name              = "${var.project_name}-cluster"
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.ecs_log_retention_days
  use_fargate_spot          = var.use_fargate_spot

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# CloudWatch Logs Module
# ===========================================

module "cloudwatch_logs" {
  source = "./modules/cloudwatch-logs"

  name_prefix        = var.project_name
  log_retention_days = var.ecs_log_retention_days

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# ECR Repositories Module
# ===========================================

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# Application Load Balancer Module
# ===========================================

module "alb" {
  source = "./modules/alb"

  name_prefix           = var.project_name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet
  alb_security_group_id = module.security_groups.alb_sg_id
  certificate_arn       = var.alb_certificate_arn
  backend_domain        = var.backend_domain
  frontend_domain       = var.frontend_domain
  backend_port          = var.backend_port
  frontend_port         = var.frontend_port

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# RDS MySQL Module
# ===========================================

module "rds" {
  source = "./modules/rds"
  count  = var.create_rds ? 1 : 0

  name_prefix        = var.project_name
  db_subnet_ids      = module.vpc.db_subnet
  security_group_ids = [module.security_groups.rds_sg_id]

  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  database_name     = var.rds_database_name
  master_username   = var.rds_master_username
  master_password   = var.rds_master_password

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# WAF for CloudFront Module
# ===========================================

module "waf" {
  source = "./modules/waf"
  count  = var.create_waf ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  name_prefix               = var.project_name
  rate_limit                = var.waf_rate_limit
  enable_cloudwatch_metrics = var.waf_enable_cloudwatch_metrics
  enable_sampled_requests   = var.waf_enable_sampled_requests

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# CloudFront Distribution Module
# ===========================================

module "cloudfront" {
  source = "./modules/cloudfront"
  count  = var.create_cloudfront ? 1 : 0

  name_prefix         = var.project_name
  alb_dns_name        = module.alb.alb_dns_name
  acm_certificate_arn = var.cloudfront_certificate_arn
  alb_certificate_arn = var.alb_certificate_arn
  aliases             = [var.backend_domain, var.frontend_domain]
  default_root_object = ""
  price_class         = "PriceClass_100"
  web_acl_id          = var.create_waf ? module.waf[0].web_acl_arn : ""

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# Bastion Host Module
# ===========================================

module "bastion" {
  source = "./modules/bastion"
  count  = var.create_bastion ? 1 : 0

  name_prefix       = var.project_name
  public_subnet_id  = module.vpc.public_subnet[0]
  security_group_id = module.security_groups.bastion_sg_id
  instance_type     = var.bastion_instance_type
  allocate_eip      = var.bastion_allocate_eip
  key_name          = var.bastion_key_name
  root_volume_size  = var.bastion_root_volume_size

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}

# ===========================================
# Secrets Manager Module
# ===========================================

module "secrets" {
  source = "./modules/secrets"
  count  = var.create_rds ? 1 : 0

  name_prefix = var.project_name
  db_username = var.rds_master_username
  db_password = var.rds_master_password
  db_host     = module.rds[0].db_instance_address
  db_port     = module.rds[0].db_instance_port
  db_name     = var.rds_database_name

  recovery_window_in_days = 0 # Immediate deletion for dev

  tags = {
    Environment = var.environment
    Project     = "Softbank2025-Cat"
  }
}
