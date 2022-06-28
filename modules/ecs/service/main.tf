resource "aws_ecs_service" "main" {
  name                               = var.name
  cluster                            = var.ecs_cluster_id
  launch_type                        = "FARGATE"
  platform_version                   = var.platform_version
  task_definition                    = var.task_definition
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  propagate_tags                     = var.propagate_tags
  enable_execute_command             = var.enable_execute_command
  tags                               = var.tags
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_controller {
    type = var.deployment_controller
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition, load_balancer]
  }
}
