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

module "container_definition" {
  source = "../ecs-container-definition"

  for_each = var.container_definitions

  operating_system_family = var.operating_system_family

  # Container Definition
  command                  = try(each.value.command, var.container_definition_defaults.command, [])
  cpu                      = try(each.value.cpu, var.container_definition_defaults.cpu, 2)
  dependencies             = try(each.value.dependencies, var.container_definition_defaults.dependencies, []) # depends_on is a reserved word
  disable_networking       = try(each.value.disable_networking, var.container_definition_defaults.disable_networking, null)
  dns_search_domains       = try(each.value.dns_search_domains, var.container_definition_defaults.dns_search_domains, [])
  dns_servers              = try(each.value.dns_servers, var.container_definition_defaults.dns_servers, [])
  docker_labels            = try(each.value.docker_labels, var.container_definition_defaults.docker_labels, {})
  docker_security_options  = try(each.value.docker_security_options, var.container_definition_defaults.docker_security_options, [])
  entrypoint               = try(each.value.entrypoint, var.container_definition_defaults.entrypoint, [])
  environment              = try(each.value.environment, var.container_definition_defaults.environment, [])
  environment_files        = try(each.value.environment_files, var.container_definition_defaults.environment_files, [])
  essential                = try(each.value.essential, var.container_definition_defaults.essential, null)
  extra_hosts              = try(each.value.extra_hosts, var.container_definition_defaults.extra_hosts, [])
  firelens_configuration   = try(each.value.firelens_configuration, var.container_definition_defaults.firelens_configuration, {})
  health_check             = try(each.value.health_check, var.container_definition_defaults.health_check, {})
  hostname                 = try(each.value.hostname, var.container_definition_defaults.hostname, null)
  image                    = try(each.value.image, var.container_definition_defaults.image, null)
  interactive              = try(each.value.interactive, var.container_definition_defaults.interactive, false)
  links                    = try(each.value.links, var.container_definition_defaults.links, [])
  linux_parameters         = try(each.value.linux_parameters, var.container_definition_defaults.linux_parameters, {})
  log_configuration        = try(each.value.log_configuration, var.container_definition_defaults.log_configuration, {})
  memory                   = try(each.value.memory, var.container_definition_defaults.memory, 512)
  memory_reservation       = try(each.value.memory_reservation, var.container_definition_defaults.memory_reservation, null)
  mount_points             = try(each.value.mount_points, var.container_definition_defaults.mount_points, [])
  name                     = try(each.value.name, each.key)
  port_mappings            = try(each.value.port_mappings, var.container_definition_defaults.port_mappings, [])
  privileged               = try(each.value.privileged, var.container_definition_defaults.privileged, false)
  pseudo_terminal          = try(each.value.pseudo_terminal, var.container_definition_defaults.pseudo_terminal, false)
  readonly_root_filesystem = try(each.value.readonly_root_filesystem, var.container_definition_defaults.readonly_root_filesystem, true)
  repository_credentials   = try(each.value.repository_credentials, var.container_definition_defaults.repository_credentials, {})
  resource_requirements    = try(each.value.resource_requirements, var.container_definition_defaults.resource_requirements, [])
  secrets                  = try(each.value.secrets, var.container_definition_defaults.secrets, [])
  start_timeout            = try(each.value.start_timeout, var.container_definition_defaults.start_timeout, 30)
  stop_timeout             = try(each.value.stop_timeout, var.container_definition_defaults.stop_timeout, 30)
  system_controls          = try(each.value.system_controls, var.container_definition_defaults.system_controls, [])
  ulimits                  = try(each.value.ulimits, var.container_definition_defaults.ulimits, [])
  user                     = try(each.value.user, var.container_definition_defaults.user, "1001:1001")
  volumes_from             = try(each.value.volumes_from, var.container_definition_defaults.volumes_from, [])
  working_directory        = try(each.value.working_directory, var.container_definition_defaults.working_directory, null)

  # CloudWatch Log Group
  service                                = var.name
  cloudwatch_log_group_retention_in_days = try(each.value.cloudwatch_log_group_retention_in_days, var.container_definition_defaults.cloudwatch_log_group_retention_in_days, 90)
  cloudwatch_log_group_kms_key_id        = try(each.value.cloudwatch_log_group_kms_key_id, var.container_definition_defaults.cloudwatch_log_group_kms_key_id, null)

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([for con in module.container_definition : con.container_definition])

  runtime_platform {
    operating_system_family = var.operating_system_family
    cpu_architecture        = var.task_cpu_architecture
  }
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
