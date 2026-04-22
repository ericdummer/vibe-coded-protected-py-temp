data "aws_ssm_parameter" "ecs_ami" {
  count = local.use_ec2 ? 1 : 0
  name  = var.ecs_optimized_ami_ssm_parameter
}

locals {
  container_image = local.use_ecr ? "${aws_ecr_repository.app[0].repository_url}:${var.container_image_tag}" : "${local.normalized_container_image_repository}:${var.container_image_tag}"
}

resource "aws_ecs_cluster" "app" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.common_tags, { Name = local.cluster_name })
}

resource "aws_launch_template" "ecs" {
  count = local.use_ec2 ? 1 : 0

  name_prefix   = "${local.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami[0].value
  instance_type = var.ec2_instance_type
  key_name      = local.normalized_ssh_key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs[0].arn
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances[0].id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.ecs_instance_root_volume_size
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.app.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true >> /etc/ecs/ecs.config
    echo ECS_LOGLEVEL=info >> /etc/ecs/ecs.config
  EOT
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-ecs-instance"
      },
    )
  }

  tags = local.common_tags
}

resource "aws_autoscaling_group" "ecs" {
  count = local.use_ec2 ? 1 : 0

  name                = "${local.name_prefix}-ecs-asg"
  desired_capacity    = var.ec2_desired_capacity
  min_size            = var.ec2_min_size
  max_size            = var.ec2_max_size
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.ecs[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "app" {
  count = local.use_ec2 ? 1 : 0

  name = "${local.name_prefix}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs[0].arn
    managed_termination_protection = upper(var.capacity_provider_managed_termination_protection)

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.capacity_provider_target_capacity
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 10
    }
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "app" {
  count = local.use_ec2 ? 1 : 0

  cluster_name = aws_ecs_cluster.app.name

  capacity_providers = [
    aws_ecs_capacity_provider.app[0].name,
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.app[0].name
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = [upper(var.ecs_launch_type)]
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    merge(
      {
        name      = local.container_name
        image     = local.container_image
        essential = true
        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = var.container_port
            protocol      = "tcp"
          }
        ]
        environment = [
          for key, value in merge(var.app_environment, { PORT = tostring(var.container_port) }) : {
            name  = key
            value = value
          }
        ]
        secrets = [
          {
            name      = "DATABASE_URL"
            valueFrom = "${aws_secretsmanager_secret.app_database.arn}:database_url::"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.app.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "app"
          }
        }
      },
      local.normalized_dockerhub_secret_arn != null ? {
        repositoryCredentials = {
          credentialsParameter = local.normalized_dockerhub_secret_arn
        }
      } : {}
    )
  ])

  lifecycle {
    precondition {
      condition     = local.use_ecr || local.normalized_container_image_repository != null
      error_message = "container_image_repository must be set when container_registry_type is dockerhub."
    }
  }

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name                              = local.service_name
  cluster                           = aws_ecs_cluster.app.id
  task_definition                   = aws_ecs_task_definition.app.arn
  desired_count                     = var.ecs_service_desired_count
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = var.wait_for_steady_state
  enable_execute_command            = true
  launch_type                       = local.use_fargate ? "FARGATE" : null
  force_new_deployment              = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "capacity_provider_strategy" {
    for_each = local.use_ec2 ? [1] : []

    content {
      capacity_provider = aws_ecs_capacity_provider.app[0].name
      weight            = 1
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = local.use_fargate ? var.assign_public_ip : false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_ecs_cluster_capacity_providers.app,
  ]

  tags = local.common_tags
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.ecs_service_max_capacity
  min_capacity       = var.ecs_service_min_capacity
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${local.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = var.cpu_target_value
  }
}

resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${local.name_prefix}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = var.memory_target_value
  }
}
