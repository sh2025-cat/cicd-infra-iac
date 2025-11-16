# ECR Repository URLs
output "gateway_api_repository_url" {
  description = "URL of the Gateway API ECR repository"
  value       = aws_ecr_repository.gateway_api.repository_url
}

output "reservation_api_repository_url" {
  description = "URL of the Reservation API ECR repository"
  value       = aws_ecr_repository.reservation_api.repository_url
}

output "inventory_api_repository_url" {
  description = "URL of the Inventory API ECR repository"
  value       = aws_ecr_repository.inventory_api.repository_url
}

output "payment_sim_api_repository_url" {
  description = "URL of the Payment Sim API ECR repository"
  value       = aws_ecr_repository.payment_sim_api.repository_url
}

output "reservation_worker_repository_url" {
  description = "URL of the Reservation Worker ECR repository"
  value       = aws_ecr_repository.reservation_worker.repository_url
}

# ECR Repository Names
output "gateway_api_repository_name" {
  description = "Name of the Gateway API ECR repository"
  value       = aws_ecr_repository.gateway_api.name
}

output "reservation_api_repository_name" {
  description = "Name of the Reservation API ECR repository"
  value       = aws_ecr_repository.reservation_api.name
}

output "inventory_api_repository_name" {
  description = "Name of the Inventory API ECR repository"
  value       = aws_ecr_repository.inventory_api.name
}

output "payment_sim_api_repository_name" {
  description = "Name of the Payment Sim API ECR repository"
  value       = aws_ecr_repository.payment_sim_api.name
}

output "reservation_worker_repository_name" {
  description = "Name of the Reservation Worker ECR repository"
  value       = aws_ecr_repository.reservation_worker.name
}

# ECR Repository ARNs
output "gateway_api_repository_arn" {
  description = "ARN of the Gateway API ECR repository"
  value       = aws_ecr_repository.gateway_api.arn
}

output "reservation_api_repository_arn" {
  description = "ARN of the Reservation API ECR repository"
  value       = aws_ecr_repository.reservation_api.arn
}

output "inventory_api_repository_arn" {
  description = "ARN of the Inventory API ECR repository"
  value       = aws_ecr_repository.inventory_api.arn
}

output "payment_sim_api_repository_arn" {
  description = "ARN of the Payment Sim API ECR repository"
  value       = aws_ecr_repository.payment_sim_api.arn
}

output "reservation_worker_repository_arn" {
  description = "ARN of the Reservation Worker ECR repository"
  value       = aws_ecr_repository.reservation_worker.arn
}

# All repositories as a map for convenience
output "ecr_repositories" {
  description = "Map of all ECR repositories with their URLs and names"
  value = {
    gateway-api = {
      name = aws_ecr_repository.gateway_api.name
      url  = aws_ecr_repository.gateway_api.repository_url
      arn  = aws_ecr_repository.gateway_api.arn
    }
    reservation-api = {
      name = aws_ecr_repository.reservation_api.name
      url  = aws_ecr_repository.reservation_api.repository_url
      arn  = aws_ecr_repository.reservation_api.arn
    }
    inventory-api = {
      name = aws_ecr_repository.inventory_api.name
      url  = aws_ecr_repository.inventory_api.repository_url
      arn  = aws_ecr_repository.inventory_api.arn
    }
    payment-sim-api = {
      name = aws_ecr_repository.payment_sim_api.name
      url  = aws_ecr_repository.payment_sim_api.repository_url
      arn  = aws_ecr_repository.payment_sim_api.arn
    }
    reservation-worker = {
      name = aws_ecr_repository.reservation_worker.name
      url  = aws_ecr_repository.reservation_worker.repository_url
      arn  = aws_ecr_repository.reservation_worker.arn
    }
  }
}
