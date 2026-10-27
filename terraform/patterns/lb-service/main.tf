provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  frontend_name = var.name
  backend_name  = "${var.name}-backend"
  namespace     = "${var.name}.local"
  vpc_cidr      = "10.90.0.0/16"
  azs           = slice(data.aws_availability_zones.available.names, 0, 2)

  container_port = 3000

  tags = {
    Blueprint  = local.frontend_name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# Self-contained infrastructure
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.frontend_name
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

  name = local.frontend_name

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

resource "aws_service_discovery_service" "frontend" {
  name = local.frontend_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {}
}

resource "aws_service_discovery_service" "backend" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {}
}

################################################################################
# Public frontend
################################################################################

module "frontend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = local.frontend_name
  desired_count = 3
  cluster_arn   = module.ecs_cluster.arn

  enable_execute_command = true

  container_definitions = {
    (local.frontend_name) = {
      image                  = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
      readonlyRootFilesystem = false

      portMappings = [{
        name          = local.frontend_name
        protocol      = "tcp"
        containerPort = local.container_port
      }]

      environment = [{
        name  = "NODEJS_URL"
        value = "http://backend.${local.namespace}:${local.container_port}"
      }]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.frontend.arn
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["ecs-task"].arn
      container_name   = local.frontend_name
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
      description                  = "Application Load Balancer"
      referenced_security_group_id = module.alb.security_group_id
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  depends_on = [module.alb]

  tags = local.tags
}

################################################################################
# Private companion backend
################################################################################

module "backend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name                   = local.backend_name
  desired_count          = 2
  cluster_arn            = module.ecs_cluster.arn
  enable_autoscaling     = false
  enable_execute_command = true

  container_definitions = {
    backend = {
      image                  = "public.ecr.aws/aws-containers/ecsdemo-nodejs:c3e96da"
      readonlyRootFilesystem = false

      portMappings = [{
        name          = "backend"
        protocol      = "tcp"
        containerPort = local.container_port
      }]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    frontend = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      description                  = "Frontend tasks"
      referenced_security_group_id = module.frontend.security_group_id
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags
}

################################################################################
# Application Load Balancer
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = local.frontend_name
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    http = {
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

      create_attachment = false
    }
  }

  tags = local.tags
}
