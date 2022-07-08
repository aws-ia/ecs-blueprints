/*====================================================================
      AWS CodeDeploy integration for Blue/Green deployments.
====================================================================*/

# ------- AWS CodeDeploy App defintion for each module -------
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = var.name

  tags = var.tags
}

# ------- AWS CodeDeploy Group for each CodeDeploy App created -------
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "deployment-group-${var.name}"
  service_role_arn       = var.codedeploy_role

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster
    service_name = var.ecs_service
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          var.alb_listener
        ]
      }

      target_group {
        name = var.tg_blue
      }

      target_group {
        name = var.tg_green
      }
    }
  }

  trigger_configuration {
    trigger_events = [
      "DeploymentSuccess",
      "DeploymentFailure",
    ]

    trigger_name       = var.trigger_name
    trigger_target_arn = var.sns_topic_arn
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [blue_green_deployment_config]
  }
}
