data "aws_region" "current" {}

################################################################################
# Service
################################################################################

resource "aws_ecs_service" "this" {
  name    = var.name
  cluster = var.ecs_cluster_id
  # launch_type                        = "FARGATE"
  platform_version        = var.platform_version
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = var.desired_count
  enable_ecs_managed_tags = var.enable_ecs_managed_tags
  propagate_tags          = var.propagate_tags
  enable_execute_command  = var.enable_execute_command

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # Capacity Provider for EC2 Launch Type
  capacity_provider_strategy {
    base              = var.cp_strategy_base
    capacity_provider = var.cp_name
    weight            = var.cp_strategy_ec2_weight
  }

  # Capacity Provider for Fargate and Fargate SPOT Launch Type

  # capacity_provider_strategy {
  #   base              = var.cp_strategy_base
  #   capacity_provider = "FARGATE"
  #   weight            = var.cp_strategy_fg_weight
  # }
  # capacity_provider_strategy {
  #   base              = 0
  #   capacity_provider = "FARGATE_SPOT"
  #   weight            = var.cp_strategy_fg_spot_weight

  # }
  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  health_check_grace_period_seconds = length(var.load_balancers) != 0 ? var.health_check_grace_period_seconds : null

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
module "task_sidecar_containers" {
  source = "../ecs-container-definition"
  count  = length(var.sidecar_container_definitions)

  container_name               = var.sidecar_container_definitions[count.index]["container_name"]
  container_image              = var.sidecar_container_definitions[count.index]["container_image"]
  essential                    = lookup(var.sidecar_container_definitions[count.index], "essential", true)
  port_mappings                = lookup(var.sidecar_container_definitions[count.index], "port_mappings", [])
  healthcheck                  = lookup(var.sidecar_container_definitions[count.index], "healthcheck", null)
  container_memory             = lookup(var.sidecar_container_definitions[count.index], "container_memory", null)
  container_memory_reservation = lookup(var.sidecar_container_definitions[count.index], "container_memory_reservation", null)
  container_cpu                = lookup(var.sidecar_container_definitions[count.index], "container_cpu", 0)
  environment_files            = lookup(var.sidecar_container_definitions[count.index], "environment_files", null)
  map_secrets                  = lookup(var.sidecar_container_definitions[count.index], "map_secrets", null)
  map_environment              = lookup(var.sidecar_container_definitions[count.index], "map_environment", null)
  log_configuration = {
    logDriver : "awslogs",
    options : {
      awslogs-region : data.aws_region.current.name,
      awslogs-group : aws_cloudwatch_log_group.this.name,
      awslogs-stream-prefix : "ecs"
    }
  }
}

module "task_main_app_container" {
  source          = "../ecs-container-definition"
  container_image = var.image
  container_name  = var.container_name
  port_mappings = [{
    protocol : "tcp",
    containerPort : var.container_port,
    hostPort : var.container_port
  }]
  log_configuration = {
    logDriver : "awslogs",
    options : {
      awslogs-region : data.aws_region.current.name,
      awslogs-group : aws_cloudwatch_log_group.this.name,
      awslogs-stream-prefix : "ecs"
    }
  }
  map_secrets     = var.map_secrets
  map_environment = var.map_environment

}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(
    concat(
      [module.task_main_app_container.json_map_object],
      [for sc in module.task_sidecar_containers : sc.json_map_object]
    )
  )

  runtime_platform {
    operating_system_family = var.task_os_family
    cpu_architecture        = var.task_cpu_architecture
  }
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
  count = var.enable_autoscaling || var.enable_scheduled_autoscaling ? 1 : 0

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


# Scheduled Scaling
# Schedule scaling is not shown in AWS console. Can view from this cli command - aws application-autoscaling describe-scheduled-actions --service-namespace ecs

resource "aws_appautoscaling_scheduled_action" "scale_up" {
  count = var.enable_scheduled_autoscaling ? 1 : 0

  name               = "ecs_scheduled_scale_up_${aws_ecs_service.this.name}"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  schedule           = var.scheduled_autoscaling_up_time
  timezone           = var.scheduled_autoscaling_timezone

  scalable_target_action {
    min_capacity = var.scheduled_autoscaling_up_min_capacity
    max_capacity = var.scheduled_autoscaling_up_max_capacity
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_down" {
  count = var.enable_scheduled_autoscaling ? 1 : 0

  name               = "ecs_scheduled_scale_down_${aws_ecs_service.this.name}"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  schedule           = var.scheduled_autoscaling_down_time
  timezone           = var.scheduled_autoscaling_timezone

  scalable_target_action {
    min_capacity = var.scheduled_autoscaling_down_min_capacity
    max_capacity = var.scheduled_autoscaling_down_max_capacity
  }
}
