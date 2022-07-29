data "aws_region" "current" {}

################################################################################
# Service
################################################################################

resource "aws_ecs_service" "this" {
  name    = var.name
  cluster = var.ecs_cluster_id
  # launch_type                        = "FARGATE"
  platform_version                   = var.platform_version
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  propagate_tags                     = var.propagate_tags
  enable_execute_command             = var.enable_execute_command
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  capacity_provider_strategy {
    base              = var.cp_strategy_base
    capacity_provider = "FARGATE"
    weight            = var.cp_strategy_fg_weight
  }
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = var.cp_strategy_fg_spot_weight

  }
  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
  }

  dynamic "service_registries" {
    for_each = var.service_registry_list
    content {
      registry_arn = service_registries.value.registry_arn
    }
  }

  deployment_controller {
    type = var.deployment_controller
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      load_balancer
    ]
  }
}

################################################################################
# Task Definition
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      cpu : var.cpu,
      memory : var.memory,
      image : var.image,
      name : var.container_name,
      networkMode : "awsvpc",
      portMappings : [
        {
          protocol : "tcp",
          containerPort : var.container_port,
          hostPort : var.container_port
        }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          awslogs-region : data.aws_region.current.name,
          awslogs-group : aws_cloudwatch_log_group.this.name,
          awslogs-stream-prefix : "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

################################################################################
# Task Role
################################################################################

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task.json

  tags = var.tags
}

data "aws_iam_policy_document" "task" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "task" {
  count = var.attach_task_role_policy ? 1 : 0

  name   = "${var.name}-task"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy
}

################################################################################
# Autoscaling
################################################################################

# ------- AWS Autoscaling target to linke the ECS cluster and service -------
resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
  resource_id        = "service/${var.ecs_cluster_id}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [
      role_arn,
    ]
  }
}

# ------- AWS Autoscaling policy using CPU allocation -------
resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "ecs_scale_cpu_service_${aws_ecs_service.this.name}"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_cpu_threshold
    scale_in_cooldown  = 60
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ------- AWS Autoscaling policy using memory allocation -------
resource "aws_appautoscaling_policy" "memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "ecs_scale_memory_service_${aws_ecs_service.this.name}"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_memory_threshold
    scale_in_cooldown  = 60
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ------- High memory alarm -------
resource "aws_cloudwatch_metric_alarm" "high_memory_policy_alarm" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "high-memory-ecs-service-${aws_ecs_service.this.name}"
  alarm_description   = "High Memory for ecs service-${aws_ecs_service.this.name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = var.autoscaling_memory_threshold

  dimensions = {
    "ServiceName" = aws_ecs_service.this.name
    "ClusterName" = var.ecs_cluster_id
  }

}

# ------- High CPU alarm -------
resource "aws_cloudwatch_metric_alarm" "high_cpu_policy_alarm" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "high-cpu-ecs-service-${aws_ecs_service.this.name}"
  alarm_description   = "High CPUPolicy Landing Page for ecs service-${aws_ecs_service.this.name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = var.autoscaling_cpu_threshold

  dimensions = {
    "ServiceName" = aws_ecs_service.this.name
    "ClusterName" = var.ecs_cluster_id
  }
}
