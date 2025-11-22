output "secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_id" {
  description = "ID of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.id
}
