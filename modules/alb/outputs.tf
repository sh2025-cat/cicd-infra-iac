# ===========================================
# ALB Outputs
# ===========================================

output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

# Backend Blue Target Group
output "backend_blue_target_group_arn" {
  description = "ARN of the backend blue target group"
  value       = aws_lb_target_group.backend_blue.arn
}

output "backend_blue_target_group_name" {
  description = "Name of the backend blue target group"
  value       = aws_lb_target_group.backend_blue.name
}

# Backend Green Target Group
output "backend_green_target_group_arn" {
  description = "ARN of the backend green target group"
  value       = aws_lb_target_group.backend_green.arn
}

output "backend_green_target_group_name" {
  description = "Name of the backend green target group"
  value       = aws_lb_target_group.backend_green.name
}

# Frontend Blue Target Group
output "frontend_blue_target_group_arn" {
  description = "ARN of the frontend blue target group"
  value       = aws_lb_target_group.frontend_blue.arn
}

output "frontend_blue_target_group_name" {
  description = "Name of the frontend blue target group"
  value       = aws_lb_target_group.frontend_blue.name
}

# Frontend Green Target Group
output "frontend_green_target_group_arn" {
  description = "ARN of the frontend green target group"
  value       = aws_lb_target_group.frontend_green.arn
}

output "frontend_green_target_group_name" {
  description = "Name of the frontend green target group"
  value       = aws_lb_target_group.frontend_green.name
}

# Listeners
output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (if created)"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}
