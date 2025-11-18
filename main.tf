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

  name_prefix   = var.project_name
  vpc_id        = module.vpc.vpc_id
  create_rds_sg = var.create_rds

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
