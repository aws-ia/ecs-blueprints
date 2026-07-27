provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  vpc_cidr          = "10.40.0.0/16"
  azs               = slice(data.aws_availability_zones.available.names, 0, 2)
  container_name    = "web"
  container_port    = 3000
  traffic_shifting  = var.deployment_strategy != "ROLLING"
  service_name      = "${var.name}-service"
  hook_function_arn = aws_lambda_function.deployment_hook.arn

  deployment_configuration = !local.traffic_shifting ? null : merge(
    {
      strategy             = var.deployment_strategy
      bake_time_in_minutes = "2"
      lifecycle_hook = {
        validation = {
          hook_target_arn  = local.hook_function_arn
          role_arn         = aws_iam_role.ecs_infrastructure.arn
          lifecycle_stages = ["POST_SCALE_UP", "POST_TEST_TRAFFIC_SHIFT"]
          hook_details     = jsonencode({ pattern = var.name })
        }
      }
    },
    var.deployment_strategy == "LINEAR" ? {
      linear_configuration = {
        step_percent              = "20"
        step_bake_time_in_minutes = "1"
      }
    } : {},
    var.deployment_strategy == "CANARY" ? {
      canary_configuration = {
        canary_percent              = "10"
        canary_bake_time_in_minutes = "2"
      }
    } : {}
  )

  tags = {
    Blueprint  = var.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = var.name

  setting = [
    {
      name  = "containerInsights"
      value = "enhanced"
    }
  ]

  tags = local.tags
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = var.name
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    production = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Production traffic"
    }
    test = {
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
      cidr_ipv4   = var.test_listener_cidr
      description = "Restricted test traffic"
    }
  }

  security_group_egress_rules = {
    service = {
      ip_protocol = "-1"
      cidr_ipv4   = local.vpc_cidr
    }
  }

  listeners = {
    production = {
      port     = 80
      protocol = "HTTP"

      fixed_response = {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }

    test = {
      port     = 8080
      protocol = "HTTP"

      fixed_response = {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }
  }

  target_groups = {
    production = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 15
        matcher             = "200-399"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }

    alternate = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 15
        matcher             = "200-399"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "production" {
  listener_arn = module.alb.listeners["production"].arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = module.alb.target_groups["production"].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  lifecycle {
    ignore_changes = [action]
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "test" {
  listener_arn = module.alb.listeners["test"].arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = module.alb.target_groups["alternate"].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  lifecycle {
    ignore_changes = [action]
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  for_each = {
    alternate  = module.alb.target_groups["alternate"].arn_suffix
    production = module.alb.target_groups["production"].arn_suffix
  }

  alarm_name          = "${var.name}-${each.key}-target-5xx"
  alarm_description   = "Roll back a deployment when the ${each.key} target group returns repeated 5xx responses."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
    TargetGroup  = each.value
  }

  tags = local.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = local.service_name
  cluster_arn   = module.ecs_cluster.arn
  desired_count = 2

  cpu                           = 256
  memory                        = 512
  enable_execute_command        = true
  availability_zone_rebalancing = "ENABLED"
  wait_for_steady_state         = true

  deployment_configuration       = local.deployment_configuration
  create_infrastructure_iam_role = false
  infrastructure_iam_role_arn    = aws_iam_role.ecs_infrastructure.arn

  deployment_circuit_breaker = local.traffic_shifting ? null : {
    enable   = true
    rollback = true
  }

  alarms = {
    alarm_names = [for alarm in aws_cloudwatch_metric_alarm.target_5xx : alarm.alarm_name]
    enable      = true
    rollback    = true
  }

  container_definitions = {
    (local.container_name) = {
      image = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"

      readonlyRootFilesystem = false
      portMappings = [{
        name          = local.container_name
        containerPort = local.container_port
        hostPort      = local.container_port
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://localhost:${local.container_port}/ || exit 1"]
        interval    = 15
        retries     = 3
        startPeriod = 20
        timeout     = 5
      }

      cloudwatch_log_group_retention_in_days = 7
    }
  }

  load_balancer = {
    service = merge(
      {
        target_group_arn = module.alb.target_groups["production"].arn
        container_name   = local.container_name
        container_port   = local.container_port
      },
      local.traffic_shifting ? {
        advanced_configuration = {
          alternate_target_group_arn = module.alb.target_groups["alternate"].arn
          production_listener_rule   = aws_lb_listener_rule.production.arn
          test_listener_rule         = aws_lb_listener_rule.test.arn
        }
      } : {}
    )
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    alb = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb.security_group_id
      description                  = "Application Load Balancer"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  depends_on = [
    aws_iam_role_policy.ecs_infrastructure_deployment_hook,
    aws_iam_role_policy_attachment.ecs_infrastructure_load_balancer,
    aws_lb_listener_rule.production,
    aws_lb_listener_rule.test,
    module.alb,
  ]

  tags = local.tags
}

data "archive_file" "deployment_hook" {
  type        = "zip"
  source_file = "${path.module}/hooks/deployment_hook.py"
  output_path = "${path.root}/.terraform/deployment-hook.zip"
}

resource "aws_iam_role" "deployment_hook" {
  name_prefix = "${var.name}-hook-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "deployment_hook" {
  name_prefix = "${var.name}-hook-"
  role        = aws_iam_role.deployment_hook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "WriteFunctionLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}-deployment-hook:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "deployment_hook" {
  name              = "/aws/lambda/${var.name}-deployment-hook"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_lambda_function" "deployment_hook" {
  function_name = "${var.name}-deployment-hook"
  description   = "No-op example of the ECS native deployment lifecycle-hook contract."
  role          = aws_iam_role.deployment_hook.arn
  runtime       = "python3.12"
  handler       = "deployment_hook.handler"

  filename         = data.archive_file.deployment_hook.output_path
  source_code_hash = data.archive_file.deployment_hook.output_base64sha256
  timeout          = 30

  depends_on = [
    aws_cloudwatch_log_group.deployment_hook,
    aws_iam_role_policy.deployment_hook,
  ]

  tags = local.tags
}

resource "aws_iam_role" "ecs_infrastructure" {
  name_prefix = "${var.name}-infra-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure_load_balancer" {
  role       = aws_iam_role.ecs_infrastructure.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}

resource "aws_iam_role_policy" "ecs_infrastructure_deployment_hook" {
  name_prefix = "${var.name}-invoke-hook-"
  role        = aws_iam_role.ecs_infrastructure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeDeploymentHook"
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.deployment_hook.arn
    }]
  })
}
