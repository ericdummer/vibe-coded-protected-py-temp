output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = aws_lb.app.dns_name
}

output "app_url" {
  description = "Preferred application URL."
  value       = local.normalized_domain_name != null ? "https://${local.normalized_domain_name}" : "http://${aws_lb.app.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "database_endpoint" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.app.address
}

output "database_secret_arn" {
  description = "Secrets Manager ARN containing database connection data and DATABASE_URL."
  value       = aws_secretsmanager_secret.app_database.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL when using the AWS registry option."
  value       = local.use_ecr ? aws_ecr_repository.app[0].repository_url : null
}

output "container_image" {
  description = "Full container image reference deployed to ECS."
  value       = local.container_image
}

output "breakglass_database_secret_arn" {
  description = "Secrets Manager ARN containing breakglass admin database credentials. Restrict access via IAM."
  value       = aws_secretsmanager_secret.breakglass_database.arn
  sensitive   = true
}
