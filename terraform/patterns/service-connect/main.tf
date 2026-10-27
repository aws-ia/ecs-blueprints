provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_partition" "current" {}

locals {
  vpc_cidr       = "10.50.0.0/16"
  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  container_port = 80

  namespace_arn = var.service_connect_namespace_arn != null ? var.service_connect_namespace_arn : aws_service_discovery_http_namespace.this[0].arn
  tls_role_arn  = var.private_ca_arn != null ? aws_iam_role.service_connect_tls[0].arn : null

  service_names = ["backend", "api", "frontend"]

  tags = {
    Blueprint  = var.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }

  container_definitions = {
    for service_name in local.service_names : service_name => {
      (service_name) = {
        image = "public.ecr.aws/docker/library/nginx:1.27.4-alpine"

        readonlyRootFilesystem = false
        portMappings = [{
          name          = service_name
          appProtocol   = "http"
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
  }

  service_connect_configurations = {
    for service_name in local.service_names : service_name => merge(
      {
        namespace = local.namespace_arn
        access_log_configuration = {
          format                   = "JSON"
          include_query_parameters = "DISABLED"
        }
        log_configuration = {
          log_driver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.service_connect.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = service_name
          }
        }
      },
      contains(["api", "backend"], service_name) ? {
        service = [{
          port_name      = service_name
          discovery_name = service_name
          client_alias = {
            dns_name = service_name
            port     = local.container_port
          }
          timeout = {
            idle_timeout_seconds        = 300
            per_request_timeout_seconds = 15
          }
          tls = var.private_ca_arn == null ? null : {
            issuer_cert_authority = {
              aws_pca_authority_arn = var.private_ca_arn
            }
            role_arn = local.tls_role_arn
          }
        }]
      } : {}
    )
  }

  service_connect_ingress = {
    service_connect = {
      from_port   = local.container_port
      to_port     = local.container_port
      ip_protocol = "tcp"
      cidr_ipv4   = local.vpc_cidr
      description = "Service Connect traffic within the VPC"
    }
  }

  service_egress = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
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

resource "aws_service_discovery_http_namespace" "this" {
  count = var.service_connect_namespace_arn == null ? 1 : 0

  name        = var.name
  description = "Service Connect namespace for ${var.name}"
  tags        = local.tags
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = var.name

  setting = [{
    name  = "containerInsights"
    value = "enhanced"
  }]

  service_connect_defaults = {
    namespace = local.namespace_arn
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "service_connect" {
  name              = "/aws/ecs/${var.name}/service-connect"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_iam_role" "service_connect_tls" {
  count = var.private_ca_arn != null ? 1 : 0

  name_prefix = "${var.name}-tls-"
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

resource "aws_iam_role_policy_attachment" "service_connect_tls" {
  count = var.private_ca_arn != null ? 1 : 0

  role       = aws_iam_role.service_connect_tls[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForServiceConnectTransportLayerSecurity"
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
        target_group_key = "frontend"
      }
    }
  }

  target_groups = {
    frontend = {
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

module "backend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${var.name}-backend"
  cluster_arn   = module.ecs_cluster.arn
  desired_count = 2

  cpu                           = 256
  memory                        = 512
  enable_execute_command        = true
  availability_zone_rebalancing = "ENABLED"

  container_definitions         = local.container_definitions["backend"]
  service_connect_configuration = local.service_connect_configurations["backend"]

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = local.service_connect_ingress
  security_group_egress_rules  = local.service_egress

  depends_on = [aws_iam_role_policy_attachment.service_connect_tls]

  tags = local.tags
}

module "api" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${var.name}-api"
  cluster_arn   = module.ecs_cluster.arn
  desired_count = 2

  cpu                           = 256
  memory                        = 512
  enable_execute_command        = true
  availability_zone_rebalancing = "ENABLED"

  container_definitions         = local.container_definitions["api"]
  service_connect_configuration = local.service_connect_configurations["api"]

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = local.service_connect_ingress
  security_group_egress_rules  = local.service_egress

  depends_on = [
    aws_iam_role_policy_attachment.service_connect_tls,
    module.backend,
  ]

  tags = local.tags
}

module "frontend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${var.name}-frontend"
  cluster_arn   = module.ecs_cluster.arn
  desired_count = 2

  cpu                           = 256
  memory                        = 512
  enable_execute_command        = true
  availability_zone_rebalancing = "ENABLED"

  container_definitions         = local.container_definitions["frontend"]
  service_connect_configuration = local.service_connect_configurations["frontend"]

  load_balancer = {
    frontend = {
      target_group_arn = module.alb.target_groups["frontend"].arn
      container_name   = "frontend"
      container_port   = local.container_port
    }
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = merge(local.service_connect_ingress, {
    alb = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb.security_group_id
      description                  = "Application Load Balancer"
    }
  })
  security_group_egress_rules = local.service_egress

  depends_on = [
    aws_iam_role_policy_attachment.service_connect_tls,
    module.api,
    module.alb,
  ]

  tags = local.tags
}
