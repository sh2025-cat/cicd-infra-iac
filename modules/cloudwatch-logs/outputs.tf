# ===========================================
# CloudWatch Logs Outputs
# ===========================================

output "backend_log_group_name" {
  description = "Backend CloudWatch log group name"
  value       = aws_cloudwatch_log_group.backend.name
}

output "backend_log_group_arn" {
  description = "Backend CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.backend.arn
}

output "frontend_log_group_name" {
  description = "Frontend CloudWatch log group name"
  value       = aws_cloudwatch_log_group.frontend.name
}

output "frontend_log_group_arn" {
  description = "Frontend CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.frontend.arn
}
