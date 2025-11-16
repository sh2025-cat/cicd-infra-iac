# ===========================================
# Security Groups Outputs
# ===========================================

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_sg_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "rds_sg_id" {
  description = "ID of the RDS security group"
  value       = var.create_rds_sg ? aws_security_group.rds[0].id : null
}
