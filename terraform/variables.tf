variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Short project name used in AWS resource naming."
  type        = string
  default     = "vibe-coded-protected"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "Existing VPC ID where the ECS service should run."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and EC2 capacity."
  type        = list(string)
}

variable "db_subnet_ids" {
  description = "Private subnet IDs for RDS. Defaults to private_subnet_ids when omitted."
  type        = list(string)
  default     = []
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the public ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted zone ID for an ALB alias record."
  type        = string
  default     = null
  nullable    = true
}

variable "domain_name" {
  description = "Optional DNS name for the ALB alias record."
  type        = string
  default     = null
  nullable    = true
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS on the ALB."
  type        = string
  default     = null
  nullable    = true
}

variable "container_registry_type" {
  description = "Container registry to use for the application image."
  type        = string
  default     = "ecr"

  validation {
    condition     = contains(["ecr", "dockerhub"], lower(var.container_registry_type))
    error_message = "container_registry_type must be either 'ecr' or 'dockerhub'."
  }
}

variable "container_image_repository" {
  description = "Repository path when using Docker Hub, such as org/app."
  type        = string
  default     = null
  nullable    = true
}

variable "container_image_tag" {
  description = "Image tag to deploy."
  type        = string
  default     = "latest"
}

variable "dockerhub_credentials_secret_arn" {
  description = "Optional Secrets Manager secret ARN containing Docker Hub registry credentials for ECS image pulls."
  type        = string
  default     = null
  nullable    = true
}

variable "ecr_repository_name" {
  description = "Optional custom ECR repository name. Defaults to project_name."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_launch_type" {
  description = "ECS launch type to use. EC2 is recommended for instance-profile-first deployments."
  type        = string
  default     = "EC2"

  validation {
    condition     = contains(["EC2", "FARGATE"], upper(var.ecs_launch_type))
    error_message = "ecs_launch_type must be either 'EC2' or 'FARGATE'."
  }
}

variable "ecs_cluster_name" {
  description = "Optional custom ECS cluster name."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights on the cluster."
  type        = bool
  default     = true
}

variable "task_cpu" {
  description = "Task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 1024
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/health"
}

variable "app_environment" {
  description = "Non-secret application environment variables to inject into the ECS task."
  type        = map(string)
  default = {
    APP_NAME = "Vibe Coded Protected API"
    DEBUG    = "false"
  }
}

variable "assign_public_ip" {
  description = "Assign a public IP to Fargate tasks. Keep false when tasks run in private subnets."
  type        = bool
  default     = false
}

variable "ecs_service_desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 2
}

variable "ecs_service_min_capacity" {
  description = "Minimum ECS service task count for autoscaling."
  type        = number
  default     = 2
}

variable "ecs_service_max_capacity" {
  description = "Maximum ECS service task count for autoscaling."
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Target average CPU utilization for ECS service autoscaling."
  type        = number
  default     = 60
}

variable "memory_target_value" {
  description = "Target average memory utilization for ECS service autoscaling."
  type        = number
  default     = 70
}

variable "wait_for_steady_state" {
  description = "Wait for ECS service steady state during terraform apply. Keep false for easier registry bootstrapping."
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS on EC2."
  type        = string
  default     = "t3.small"
}

variable "ec2_desired_capacity" {
  description = "Desired ECS instance count in the backing Auto Scaling Group."
  type        = number
  default     = 2
}

variable "ec2_min_size" {
  description = "Minimum ECS instance count in the backing Auto Scaling Group."
  type        = number
  default     = 2
}

variable "ec2_max_size" {
  description = "Maximum ECS instance count in the backing Auto Scaling Group."
  type        = number
  default     = 4
}

variable "ecs_optimized_ami_ssm_parameter" {
  description = "SSM parameter name for the ECS-optimized AMI."
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable "ecs_instance_root_volume_size" {
  description = "Root EBS volume size in GiB for ECS EC2 instances."
  type        = number
  default     = 30
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for ECS instances."
  type        = string
  default     = null
  nullable    = true
}

variable "capacity_provider_target_capacity" {
  description = "Target capacity percentage for ECS managed scaling."
  type        = number
  default     = 100
}

variable "capacity_provider_managed_termination_protection" {
  description = "Managed termination protection mode for the ECS capacity provider."
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["DISABLED", "ENABLED"], upper(var.capacity_provider_managed_termination_protection))
    error_message = "capacity_provider_managed_termination_protection must be ENABLED or DISABLED."
  }
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "vibedb"
}

variable "db_username" {
  description = "PostgreSQL database username."
  type        = string
  default     = "vibeapp"
}

variable "db_port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled RDS storage in GiB."
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "Optional PostgreSQL engine version."
  type        = string
  default     = null
  nullable    = true
}

variable "db_parameter_group_family" {
  description = "DB parameter group family."
  type        = string
  default     = "postgres16"
}

variable "db_backup_retention_period" {
  description = "Backup retention in days."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for the RDS instance."
  type        = bool
  default     = false
}

variable "db_publicly_accessible" {
  description = "Whether the RDS instance should be publicly accessible."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when destroying the database."
  type        = bool
  default     = false
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights for RDS."
  type        = bool
  default     = false
}

variable "db_secret_recovery_window_in_days" {
  description = "Secrets Manager recovery window in days for the generated DB secret."
  type        = number
  default     = 7
}

variable "cloudwatch_log_retention_in_days" {
  description = "CloudWatch Logs retention for ECS application logs."
  type        = number
  default     = 30
}

variable "alarm_topic_arn" {
  description = "Optional SNS topic ARN for CloudWatch alarm notifications."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_waf" {
  description = "Create and attach a regional WAFv2 Web ACL to the ALB."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Rate-based rule limit for the WAF."
  type        = number
  default     = 1000
}
