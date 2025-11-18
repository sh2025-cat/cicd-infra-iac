output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.mysql.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "db_instance_address" {
  description = "RDS instance address"
  value       = aws_db_instance.mysql.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mysql.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.mysql.db_name
}

output "db_master_username" {
  description = "Master username"
  value       = aws_db_instance.mysql.username
  sensitive   = true
}
