locals {
  normalized_route53_zone_id            = var.route53_zone_id != null && trim(var.route53_zone_id) != "" ? var.route53_zone_id : null
  normalized_domain_name                = var.domain_name != null && trim(var.domain_name) != "" ? var.domain_name : null
  normalized_acm_certificate_arn        = var.acm_certificate_arn != null && trim(var.acm_certificate_arn) != "" ? var.acm_certificate_arn : null
  normalized_container_image_repository = var.container_image_repository != null && trim(var.container_image_repository) != "" ? var.container_image_repository : null
  normalized_dockerhub_secret_arn       = var.dockerhub_credentials_secret_arn != null && trim(var.dockerhub_credentials_secret_arn) != "" ? var.dockerhub_credentials_secret_arn : null
  normalized_ecr_repository_name        = var.ecr_repository_name != null && trim(var.ecr_repository_name) != "" ? var.ecr_repository_name : null
  normalized_ecs_cluster_name           = var.ecs_cluster_name != null && trim(var.ecs_cluster_name) != "" ? var.ecs_cluster_name : null
  normalized_ssh_key_name               = var.ssh_key_name != null && trim(var.ssh_key_name) != "" ? var.ssh_key_name : null
  normalized_alarm_topic_arn            = var.alarm_topic_arn != null && trim(var.alarm_topic_arn) != "" ? var.alarm_topic_arn : null
  name_prefix                           = "${var.project_name}-${var.environment}"
  use_ec2                               = upper(var.ecs_launch_type) == "EC2"
  use_fargate                           = upper(var.ecs_launch_type) == "FARGATE"
  use_ecr                               = lower(var.container_registry_type) == "ecr"
  cluster_name                          = coalesce(local.normalized_ecs_cluster_name, "${local.name_prefix}-cluster")
  service_name                          = "${local.name_prefix}-service"
  container_name                        = "${var.project_name}-app"
  db_subnet_ids                         = length(var.db_subnet_ids) > 0 ? var.db_subnet_ids : var.private_subnet_ids
  ecr_repository_name                   = coalesce(local.normalized_ecr_repository_name, var.project_name)
  create_https_listener                 = local.normalized_acm_certificate_arn != null
  alarm_actions                         = local.normalized_alarm_topic_arn != null ? [local.normalized_alarm_topic_arn] : []

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags,
  )
}
