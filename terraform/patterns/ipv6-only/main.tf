provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_cidr       = "10.80.0.0/16"
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

  azs            = local.azs
  public_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  enable_ipv6 = true

  # ALB nodes use dual-stack public subnets. ECS tasks use IPv6-native private subnets.
  public_subnet_ipv6_prefixes                   = [0, 1]
  public_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_native                    = true
  private_subnet_ipv6_prefixes                  = [2, 3]

  # DNS64 synthesizes reachable-looking addresses for IPv4-only hosts, but the
  # NAT64 path it depends on requires a NAT gateway this pattern does not create.
  # Disable it so IPv4-only dependencies fail fast at DNS instead of timing out.
  private_subnet_enable_dns64 = false

  enable_nat_gateway     = false
  create_egress_only_igw = true

  tags = local.tags
}

# The account-level dualStackIPv6 default is a Region-wide ECS setting shared by every
# service in the account. This pattern does NOT manage it by default (manage_account_setting
# = false) so that a single `terraform apply`/`terraform destroy` never touches an
# account-wide setting other workloads may rely on — enable it once as a prerequisite (see
# README). In a dedicated account you may set manage_account_setting = true to have this
# root enable it; note that `terraform destroy` will then disable it again.
resource "aws_ecs_account_setting_default" "dual_stack_ipv6" {
  count = var.manage_account_setting ? 1 : 0

  name  = "dualStackIPv6"
  value = "enabled"
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = var.name

  setting = [{
    name  = "containerInsights"
    value = "enhanced"
  }]

  tags = local.tags
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = var.name
  load_balancer_type = "application"
  ip_address_type    = "dualstack-without-public-ipv4"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    http_ipv6 = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv6   = "::/0"
      description = "Public IPv6 HTTP endpoint"
    }
  }

  security_group_egress_rules = {
    service_ipv6 = {
      ip_protocol = "-1"
      cidr_ipv6   = "::/0"
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
      protocol        = "HTTP"
      port            = local.container_port
      target_type     = "ip"
      ip_address_type = "ipv6"

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
  cluster_arn   = module.ecs_cluster.arn
  desired_count = 2

  cpu                           = 256
  memory                        = 512
  platform_version              = "LATEST"
  availability_zone_rebalancing = "ENABLED"

  container_definitions = {
    (local.container_name) = {
      image = "docker.io/library/httpd:2.4.62-alpine"

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
      description                  = "Application Load Balancer over IPv6"
    }
  }

  security_group_egress_rules = {
    all_ipv6 = {
      ip_protocol = "-1"
      cidr_ipv6   = "::/0"
    }
  }

  depends_on = [
    aws_ecs_account_setting_default.dual_stack_ipv6, # empty list when unmanaged; still valid
    module.alb,
  ]
  tags = local.tags
}
