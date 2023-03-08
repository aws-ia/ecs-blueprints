provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "ex-github-action"
  region = "us-west-2"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_service" {
  source = "github.com/clowdhaus/terraform-aws-ecs//modules/service"
  # version = "~> 5.0"

  name    = local.name
  cluster = module.ecs.cluster_name

  # These settings will be ignored after the initial create
  ignore_task_definition_changes = true
  desired_count                  = 3
  container_definitions = {
    default = {
      name  = local.container_name
      image = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    }
  }

  subnet_ids = module.vpc.private_subnets
  security_group_rules = {
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = local.tags
}

module "ecs" {
  source = "github.com/clowdhaus/terraform-aws-ecs"
  # version = "~> 5.0"

  cluster_name = local.name

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
# Supporting Resources
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
