# ===========================================
# RDS Subnet Group
# ===========================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# ===========================================
# RDS Parameter Group (MySQL 8.x)
# ===========================================

resource "aws_db_parameter_group" "mysql8" {
  name   = "${var.name_prefix}-mysql8-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql8-params"
  })
}

# ===========================================
# RDS Instance (MySQL 8.x - Development)
# ===========================================

resource "aws_db_instance" "mysql" {
  identifier        = "${var.name_prefix}-mysql"
  engine            = "mysql"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.mysql8.name
  vpc_security_group_ids = var.security_group_ids

  # Development settings - No backups
  backup_retention_period    = 0
  skip_final_snapshot        = true
  deletion_protection        = false
  multi_az                   = false
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  # Performance and monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled    = false

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-mysql"
    Environment = "development"
  })
}
