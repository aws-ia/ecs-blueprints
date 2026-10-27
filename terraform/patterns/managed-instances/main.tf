provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ebs_encryption_by_default" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  partition      = data.aws_partition.current.partition
  vpc_cidr       = "10.60.0.0/16"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  container_name = "web"
  container_port = 80

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

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = local.tags
}

resource "aws_security_group" "managed_instances" {
  name_prefix = "${var.name}-instances-"
  description = "ECS Managed Instances"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-instances" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "managed_instances_alb" {
  security_group_id            = aws_security_group.managed_instances.id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = local.container_port
  to_port                      = local.container_port
  ip_protocol                  = "tcp"
  description                  = "Application Load Balancer"
}

resource "aws_vpc_security_group_egress_rule" "managed_instances" {
  security_group_id = aws_security_group.managed_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound access for image pulls and telemetry"
}

################################################################################
# Managed Instances IAM roles
################################################################################

resource "aws_iam_role" "node" {
  name_prefix = "${var.name}-node-"
  description = "ECS Managed Instances node role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "node" {
  name_prefix = "${var.name}-node-"
  role        = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverPollEndpoint"
        Effect   = "Allow"
        Action   = "ecs:DiscoverPollEndpoint"
        Resource = "*"
      },
      {
        Sid      = "RegisterContainerInstance"
        Effect   = "Allow"
        Action   = "ecs:RegisterContainerInstance"
        Resource = aws_ecs_cluster.this.arn
      },
      {
        Sid    = "Poll"
        Effect = "Allow"
        Action = "ecs:Poll"
        Resource = [
          "arn:${local.partition}:ecs:${var.aws_region}:${local.account_id}:container-instance/*",
          "arn:${local.partition}:ecs:${var.aws_region}:${local.account_id}:task-set/*",
        ]
      },
      {
        Sid    = "Telemetry"
        Effect = "Allow"
        Action = [
          "ecs:StartTelemetrySession",
          "ecs:PutSystemLogEvents",
        ]
        Resource = "arn:${local.partition}:ecs:${var.aws_region}:${local.account_id}:container-instance/*"
      },
      {
        Sid    = "SubmitStateChanges"
        Effect = "Allow"
        Action = [
          "ecs:SubmitAttachmentStateChanges",
          "ecs:SubmitTaskStateChange",
        ]
        Resource = aws_ecs_cluster.this.arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "node" {
  name_prefix = "${var.name}-node-"
  role        = aws_iam_role.node.name
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "infrastructure" {
  name_prefix = "${var.name}-infra-"
  description = "ECS infrastructure role for Managed Instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "infrastructure" {
  name_prefix = "${var.name}-infra-"
  role        = aws_iam_role.infrastructure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateLaunchTemplate"
        Effect   = "Allow"
        Action   = "ec2:CreateLaunchTemplate"
        Resource = "arn:${local.partition}:ec2:${var.aws_region}:${local.account_id}:launch-template/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/AmazonECSManaged" = "true"
          }
        }
      },
      {
        Sid    = "ManageLaunchTemplateVersions"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate",
        ]
        Resource = "arn:${local.partition}:ec2:${var.aws_region}:${local.account_id}:launch-template/*"
        Condition = {
          StringEquals = {
            "ec2:ManagedResourceOperator" = "ecs.amazonaws.com"
          }
        }
      },
      {
        Sid    = "CreateFleetForManagedResources"
        Effect = "Allow"
        Action = "ec2:CreateFleet"
        Resource = [
          "arn:${local.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:volume/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/AmazonECSManaged" = "true"
          }
        }
      },
      {
        Sid    = "CreateFleetForSupportingResources"
        Effect = "Allow"
        Action = "ec2:CreateFleet"
        Resource = [
          "arn:${local.partition}:ec2:${var.aws_region}:*:subnet/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:image/*",
        ]
      },
      {
        Sid    = "RunManagedInstances"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:network-interface/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/AmazonECSManaged" = "true"
          }
        }
      },
      {
        Sid      = "RunInstancesFromManagedLaunchTemplates"
        Effect   = "Allow"
        Action   = "ec2:RunInstances"
        Resource = "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/AmazonECSManaged" = "true"
          }
        }
      },
      {
        Sid    = "RunInstancesWithSupportingResources"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:${local.partition}:ec2:${var.aws_region}:*:subnet/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:image/*",
        ]
      },
      {
        Sid    = "TagManagedResourcesOnCreate"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:${local.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${local.partition}:ec2:${var.aws_region}:*:volume/*",
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateFleet",
              "CreateLaunchTemplate",
              "RunInstances",
            ]
          }
        }
      },
      {
        Sid      = "PassNodeRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.node.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Sid      = "CreateSpotServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
      },
      {
        Sid    = "DescribeEC2Resources"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# Capacity provider
################################################################################

resource "aws_ecs_capacity_provider" "this" {
  name    = "mi-${var.name}-${lower(replace(var.capacity_option_type, "_", "-"))}"
  cluster = aws_ecs_cluster.this.name

  managed_instances_provider {
    infrastructure_role_arn = aws_iam_role.infrastructure.arn
    propagate_tags          = "CAPACITY_PROVIDER"

    infrastructure_optimization {
      scale_in_after = var.scale_in_after_seconds
    }

    instance_launch_template {
      capacity_option_type     = var.capacity_option_type
      ec2_instance_profile_arn = aws_iam_instance_profile.node.arn
      monitoring               = "DETAILED"

      instance_requirements {
        instance_generations = ["current"]
        cpu_manufacturers    = ["intel", "amd"]
        local_storage        = var.require_instance_store ? "required" : "included"
        local_storage_types  = var.require_instance_store ? ["ssd"] : null

        memory_mib {
          min = 2048
          max = 8192
        }

        vcpu_count {
          min = 1
          max = 4
        }

        dynamic "total_local_storage_gb" {
          for_each = var.require_instance_store ? [1] : []

          content {
            min = 20
          }
        }
      }

      network_configuration {
        subnets         = module.vpc.private_subnets
        security_groups = [aws_security_group.managed_instances.id]
      }

      storage_configuration {
        storage_size_gib = 30
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.infrastructure,
    aws_iam_role_policy.node,
    aws_vpc_security_group_egress_rule.managed_instances,
    module.vpc,
  ]

  tags = local.tags

  lifecycle {
    precondition {
      condition     = data.aws_ebs_encryption_by_default.current.enabled
      error_message = "EBS encryption by default must be enabled in ${var.aws_region} before creating Managed Instances capacity. See README.md Prerequisites or run: aws ec2 enable-ebs-encryption-by-default --region ${var.aws_region}"
    }
  }
}

resource "time_sleep" "capacity_provider" {
  create_duration  = "20s"
  destroy_duration = format("%ds", var.scale_in_after_seconds + 60)

  triggers = {
    capacity_provider_arn = aws_ecs_capacity_provider.this.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }

  depends_on = [time_sleep.capacity_provider]
}

################################################################################
# Managed Daemon
################################################################################

resource "aws_cloudwatch_log_group" "daemon" {
  name              = "/aws/ecs/${var.name}/managed-daemon"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_iam_role" "daemon_execution" {
  name_prefix = "${var.name}-daemon-"

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

resource "aws_iam_role_policy_attachment" "daemon_execution" {
  role       = aws_iam_role.daemon_execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_daemon_task_definition" "telemetry" {
  family             = "${var.name}-telemetry"
  execution_role_arn = aws_iam_role.daemon_execution.arn

  container_definition {
    name                     = "node-heartbeat"
    image                    = "public.ecr.aws/docker/library/busybox:1.36"
    essential                = true
    cpu                      = 64
    memory                   = 128
    readonly_root_filesystem = true
    entry_point              = ["/bin/sh", "-c"]
    command                  = ["while true; do echo \"managed-daemon heartbeat $(date -u)\"; sleep 300; done"]

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.daemon.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "daemon"
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.daemon_execution]
  tags       = local.tags
}

resource "aws_ecs_daemon" "telemetry" {
  name                       = "${var.name}-telemetry"
  cluster_arn                = aws_ecs_cluster.this.arn
  capacity_provider_arns     = [aws_ecs_capacity_provider.this.arn]
  daemon_task_definition_arn = aws_ecs_daemon_task_definition.telemetry.arn
  enable_ecs_managed_tags    = true
  propagate_tags             = "DAEMON"

  deployment_configuration {
    bake_time_in_minutes = 1
    drain_percent        = 100
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]
  tags       = local.tags
}

################################################################################
# Web service
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = var.name
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Public HTTP endpoint"
    }
  }

  security_group_egress_rules = {
    service = {
      ip_protocol = "-1"
      cidr_ipv4   = local.vpc_cidr
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "web"
      }
    }
  }

  target_groups = {
    web = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 15
        matcher             = "200"
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

module "service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${var.name}-web"
  cluster_arn   = aws_ecs_cluster.this.arn
  desired_count = 2

  requires_compatibilities = ["MANAGED_INSTANCES"]
  cpu                      = 256
  memory                   = 512

  capacity_provider_strategy = {
    managed = {
      capacity_provider = aws_ecs_capacity_provider.this.name
      weight            = 1
    }
  }

  container_definitions = {
    (local.container_name) = {
      image = "public.ecr.aws/docker/library/httpd:2.4.62-alpine"

      readonlyRootFilesystem = false
      portMappings = [{
        name          = local.container_name
        containerPort = local.container_port
        hostPort      = local.container_port
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost/ || exit 1"]
        interval    = 15
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }

      cloudwatch_log_group_retention_in_days = 7
    }
  }

  load_balancer = {
    web = {
      target_group_arn = module.alb.target_groups["web"].arn
      container_name   = local.container_name
      container_port   = local.container_port
    }
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
    aws_ecs_cluster_capacity_providers.this,
    module.alb,
  ]
  tags = local.tags
}
