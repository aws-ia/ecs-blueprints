provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name      = var.name
  region    = var.aws_region
  namespace = "${var.name}.local"
  vpc_cidr  = "10.92.0.0/16"
  azs       = slice(data.aws_availability_zones.available.names, 0, 2)

  container_port = 3000 # Container port is specific to this app example
  container_name = var.name

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/ecs-blueprints"
  }
}

################################################################################
# Self-contained infrastructure
################################################################################

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

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = local.name

  setting = [{
    name  = "containerInsights"
    value = "enhanced"
  }]

  tags = local.tags
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = local.namespace
  vpc  = module.vpc.vpc_id
  tags = local.tags
}

################################################################################
# x86 (amd64) Fargate service
################################################################################

module "ecs_service_amd64" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${local.name}-amd64"
  desired_count = 3
  cluster_arn   = module.ecs_cluster.arn

  # Task Definition
  enable_execute_command = true

  container_definitions = {
    (local.container_name) = {
      image                  = module.ecr.repository_url
      readonlyRootFilesystem = false

      portMappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.amd64.arn
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb_amd64.target_groups["ecs-task"].arn
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    ingress_alb_service = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      description                  = "Service port"
      referenced_security_group_id = module.alb_amd64.security_group_id
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  depends_on = [module.alb_amd64]

  tags = local.tags
}

resource "aws_service_discovery_service" "amd64" {
  name = local.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
  }
}

################################################################################
# Graviton (arm64) Fargate service
################################################################################

module "ecs_service_arm64" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = "${local.name}-arm64"
  desired_count = 3
  cluster_arn   = module.ecs_cluster.arn

  # Task Definition
  enable_execute_command = true
  runtime_platform = {
    cpu_architecture = "ARM64"
  }

  container_definitions = {
    (local.container_name) = {
      image                  = module.ecr.repository_url
      readonlyRootFilesystem = false

      portMappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.arm64.arn
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb_arm64.target_groups["ecs-task"].arn
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    ingress_alb_service = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      description                  = "Service port"
      referenced_security_group_id = module.alb_arm64.security_group_id
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  depends_on = [module.alb_arm64]

  tags = local.tags
}

resource "aws_service_discovery_service" "arm64" {
  name = "${local.name}-arm64"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
  }
}

################################################################################
# Application Load Balancers
################################################################################

module "alb_amd64" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = "${local.name}-amd64"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  # For example only
  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
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
        target_group_key = "ecs-task"
      }
    }
  }

  target_groups = {
    ecs-task = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200-299"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }

  tags = local.tags
}

module "alb_arm64" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = "${local.name}-arm64"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  # For example only
  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
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
        target_group_key = "ecs-task"
      }
    }
  }

  target_groups = {
    ecs-task = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200-299"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}
