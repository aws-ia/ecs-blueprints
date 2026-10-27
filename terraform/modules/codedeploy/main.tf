data "aws_partition" "current" {}

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = var.name

  tags = var.tags
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_config_name = var.deployment_config_name
  deployment_group_name  = "deployment-group-${var.name}"
  service_role_arn       = var.service_role != null ? var.service_role : aws_iam_role.this[0].arn

  lifecycle {
    precondition {
      condition     = var.create_iam_role || var.service_role != null
      error_message = "No CodeDeploy service role is available: set create_iam_role = true to have the module create one, or provide an existing role ARN via service_role."
    }

    ignore_changes = [blue_green_deployment_config]
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = var.action_on_timeout
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
}

################################################################################
# IAM
################################################################################

data "aws_iam_policy_document" "assume_role_policy" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid     = "CodedeployAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_use_name_prefix ? null : var.iam_role_name
  name_prefix        = var.iam_role_use_name_prefix ? "${var.iam_role_name}-" : null
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.create_iam_role ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.this[0].name
}
