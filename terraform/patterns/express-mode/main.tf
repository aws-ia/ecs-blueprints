provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false

  keepers = {
    name = var.name
  }
}

locals {
  name           = "${var.name}-${random_string.suffix.result}"
  vpc_cidr       = "10.70.0.0/16"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  container_port = 3000

  tags = {
    Blueprint  = var.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = local.tags
}

resource "aws_iam_role" "express_infrastructure" {
  name_prefix = "${local.name}-infra-"

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

resource "aws_iam_role_policy_attachment" "express_infrastructure" {
  role       = aws_iam_role.express_infrastructure.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

resource "aws_iam_role_policy" "express_infrastructure_control_plane" {
  name_prefix = "${local.name}-control-plane-"
  role        = aws_iam_role.express_infrastructure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.this.name}/*"
      },
      {
        Effect   = "Allow"
        Action   = "cloudwatch:DescribeAlarms"
        Resource = "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:*"
      },
      {
        Effect   = "Allow"
        Action   = "ec2:DescribeInternetGateways"
        Resource = "*"
      },
    ]
  })
}

################################################################################
# Image-to-HTTPS quick start
################################################################################

resource "aws_iam_role" "quick_start_execution" {
  name_prefix = "${local.name}-quick-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "quick_start_execution" {
  role       = aws_iam_role.quick_start_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "quick_start" {
  name              = "/aws/ecs/${local.name}/quick"
  retention_in_days = 7
  tags              = local.tags
}

module "quick_start" {
  source  = "terraform-aws-modules/ecs/aws//modules/express-service"
  version = "7.5.0"

  name    = "${local.name}-quick"
  cluster = aws_ecs_cluster.this.arn
  cpu     = "512"
  memory  = "1024"

  health_check_path = "/"

  create_infrastructure_iam_role = false
  infrastructure_iam_role_arn    = aws_iam_role.express_infrastructure.arn
  create_execution_iam_role      = false
  execution_iam_role_arn         = aws_iam_role.quick_start_execution.arn

  # Express Mode provisions its own load balancer whose scheme follows the subnets it is
  # given: public subnets yield an internet-facing endpoint (the point of a quick start),
  # private subnets yield an internal one. Use public subnets so the endpoint is reachable.
  network_configuration = {
    subnets = module.vpc.public_subnets
  }

  create_cloudwatch_log_group = false

  primary_container = {
    container_port = local.container_port
    image          = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
    aws_logs_configuration = {
      log_group         = aws_cloudwatch_log_group.quick_start.name
      log_stream_prefix = "ecs"
    }
  }

  scaling_target = {
    auto_scaling_metric       = "AVERAGE_CPU"
    auto_scaling_target_value = 70
    max_task_count            = 4
    min_task_count            = 1
  }

  vpc_id = module.vpc.vpc_id
  security_group_ingress_rules = {
    app_port_from_vpc = {
      from_port   = local.container_port
      to_port     = local.container_port
      ip_protocol = "tcp"
      description = "Application port from the Express-managed load balancer"
      cidr_ipv4   = local.vpc_cidr
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy.express_infrastructure_control_plane,
    aws_iam_role_policy_attachment.express_infrastructure,
    aws_iam_role_policy_attachment.quick_start_execution,
  ]
}

################################################################################
# Custom task definition variant
################################################################################

resource "aws_cloudwatch_log_group" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  name              = "/aws/ecs/${local.name}/custom"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_iam_role" "custom_execution" {
  count = var.enable_custom_task_definition ? 1 : 0

  name_prefix = "${local.name}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "custom_execution" {
  count = var.enable_custom_task_definition ? 1 : 0

  role       = aws_iam_role.custom_execution[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "custom_task" {
  count = var.enable_custom_task_definition ? 1 : 0

  name_prefix = "${local.name}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "custom_task_logs" {
  count = var.enable_custom_task_definition ? 1 : 0

  name_prefix = "${local.name}-logs-"
  role        = aws_iam_role.custom_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.custom[0].arn}:*"
    }]
  })
}

resource "aws_security_group" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  name_prefix = "${local.name}-custom-"
  description = "Custom-task-definition Express Gateway service"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-custom" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  security_group_id = aws_security_group.custom[0].id
  cidr_ipv4         = local.vpc_cidr
  from_port         = local.container_port
  to_port           = local.container_port
  ip_protocol       = "tcp"
  description       = "Application port from the Express-managed load balancer"
}

resource "aws_vpc_security_group_egress_rule" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  security_group_id = aws_security_group.custom[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound image, logs, and application traffic"
}

resource "aws_ecs_task_definition" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  family                   = "${local.name}-custom"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.custom_execution[0].arn
  task_role_arn            = aws_iam_role.custom_task[0].arn

  # Express Mode resolves its load-balanced container from the first entry.
  container_definitions = jsonencode([
    {
      name                   = "Main"
      image                  = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
      essential              = true
      cpu                    = 384
      memoryReservation      = 512
      readonlyRootFilesystem = false
      portMappings = [{
        name          = "web"
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
      dependsOn = [{
        containerName = "log-router"
        condition     = "START"
      }]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name              = "cloudwatch"
          region            = var.aws_region
          log_group_name    = aws_cloudwatch_log_group.custom[0].name
          log_stream_prefix = "web-"
          auto_create_group = "false"
        }
      }
    },
    {
      name              = "log-router"
      image             = "public.ecr.aws/aws-observability/aws-for-fluent-bit:3.4.10"
      essential         = true
      cpu               = 64
      memoryReservation = 128
      user              = "0"
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.custom[0].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "router"
        }
      }
    },
  ])

  depends_on = [
    aws_iam_role_policy.custom_task_logs,
    aws_iam_role_policy_attachment.custom_execution,
  ]

  tags = local.tags
}

resource "aws_cloudformation_stack" "custom" {
  count = var.enable_custom_task_definition ? 1 : 0

  name = "${local.name}-custom-express"

  parameters = {
    ClusterArn            = aws_ecs_cluster.this.arn
    InfrastructureRoleArn = aws_iam_role.express_infrastructure.arn
    SecurityGroupId       = aws_security_group.custom[0].id
    SubnetA               = module.vpc.private_subnets[0]
    SubnetB               = module.vpc.private_subnets[1]
    TaskDefinitionArn     = aws_ecs_task_definition.custom[0].arn
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "ECS Express Gateway service using a custom task definition"
    Parameters = {
      ClusterArn = {
        Type = "String"
      }
      InfrastructureRoleArn = {
        Type = "String"
      }
      SecurityGroupId = {
        Type = "String"
      }
      SubnetA = {
        Type = "String"
      }
      SubnetB = {
        Type = "String"
      }
      TaskDefinitionArn = {
        Type = "String"
      }
    }
    Resources = {
      ExpressService = {
        Type = "AWS::ECS::ExpressGatewayService"
        Properties = {
          Cluster               = { Ref = "ClusterArn" }
          InfrastructureRoleArn = { Ref = "InfrastructureRoleArn" }
          TaskDefinitionArn     = { Ref = "TaskDefinitionArn" }
          HealthCheckPath       = "/"
          NetworkConfiguration = {
            SecurityGroups = [{ Ref = "SecurityGroupId" }]
            Subnets = [
              { Ref = "SubnetA" },
              { Ref = "SubnetB" },
            ]
          }
          ScalingTarget = {
            AutoScalingMetric      = "AVERAGE_CPU"
            AutoScalingTargetValue = 70
            MinTaskCount           = 1
            MaxTaskCount           = 4
          }
          Tags = [
            {
              Key   = "Blueprint"
              Value = var.name
            },
            {
              Key   = "GithubRepo"
              Value = "github.com/aws-ia/ecs-blueprints"
            },
          ]
        }
      }
    }
    Outputs = {
      Endpoint = {
        Value = { "Fn::GetAtt" = ["ExpressService", "Endpoint"] }
      }
      ServiceArn = {
        Value = { "Fn::GetAtt" = ["ExpressService", "ServiceArn"] }
      }
    }
  })

  timeouts {
    create = "60m"
    delete = "60m"
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy.express_infrastructure_control_plane,
    aws_iam_role_policy_attachment.express_infrastructure,
  ]
}
