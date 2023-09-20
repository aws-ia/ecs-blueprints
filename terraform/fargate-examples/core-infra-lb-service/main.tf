provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = "ecsdemo-frontend"
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  container_image = "public.ecr.aws/aws-containers/ecsdemo-frontend"
  container_port  = 3000 # Container port is specific to this app example
  container_name  = "app"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# Network
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  tags = local.tags
}

################################################################################
# Service discovery namespaces
################################################################################

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "default.${local.name}.local"
  description = "Service discovery namespace.clustername.local"
  vpc         = module.vpc.vpc_id

  tags = local.tags
}

################################################################################
# ECS Cluster
################################################################################

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = local.name

  cluster_service_connect_defaults = {
    namespace = aws_service_discovery_private_dns_namespace.this.arn
  }

  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  # Shared task execution role
  create_task_exec_iam_role = true
  # Allow read access to all SSM params in current account for demo
  task_exec_ssm_param_arns = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  # Allow read access to all secrets in current account for demo
  task_exec_secret_arns = ["arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:*"]

  tags = local.tags
}

################################################################################
# ECS Service + ALB
################################################################################

module "service_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.3"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id = module.vpc.vpc_id

  # public ALB
  subnets  = module.vpc.public_subnets
  internal = false
  # OR
  # private ALB
  # subnets = module.vpc.private_subnets
  # internal = true

  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [for s in module.vpc.private_subnets_cidr_blocks : s]
    }
  }

  http_tcp_listeners = [
    {
      port               = "80"
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tg"
      backend_protocol = "HTTP"
      backend_port     = local.container_port
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = local.container_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

resource "aws_service_discovery_service" "this" {
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
    failure_threshold = 1
  }
}

module "ecs_service_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = local.name
  desired_count      = 3
  cluster_arn        = module.ecs.cluster_arn
  enable_autoscaling = false

  subnet_ids = module.vpc.private_subnets
  security_group_rules = {
    ingress_alb_service = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.service_alb.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  load_balancer = [{
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = element(module.service_alb.target_group_arns, 0)
  }]

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  service_connect_configuration = {
    enabled = false
  }

  # Task Definition
  create_iam_role        = false
  task_exec_iam_role_arn = module.ecs.task_exec_iam_role_arn
  enable_execute_command = true

  container_definitions = {
    main_container = {
      name                     = local.container_name
      image                    = local.container_image
      readonly_root_filesystem = false

      port_mappings = [{
        protocol : "tcp",
        containerPort : local.container_port
        hostPort : local.container_port
      }],
      "environment" = [
        {
          "name"  = "NODEJS_URL",
          "value" = "http://ecsdemo-backend.default.core-infra.local:3000"
        },
      ]
    }
  }

  ignore_task_definition_changes = false

  tags = local.tags
}
