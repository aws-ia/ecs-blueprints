provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  name   = var.core_stack_name
  region = var.aws_region

  vpc_cidr       = var.vpc_cidr
  num_of_subnets = min(length(data.aws_availability_zones.available.names), 3)
  azs            = slice(data.aws_availability_zones.available.names, 0, local.num_of_subnets)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-ecs-blueprints"
  }
  task_execution_role_managed_policy_arn = ["arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.0"

  cluster_name = local.name

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.this.name
      }
    }
  }

  # Capacity provider
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 0
        base   = 0
      }
    }
  }

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

  enable_nat_gateway   = var.enable_nat_gw
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

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${local.name}"
  retention_in_days = 7

  tags = local.tags
}

################################################################################
# Service discovery namespaces
################################################################################

resource "aws_service_discovery_private_dns_namespace" "sd_namespaces" {
  for_each = toset(var.namespaces)

  name        = "${each.key}.${module.ecs.cluster_name}.local"
  description = "service discovery namespace.clustername.local"
  vpc         = module.vpc.vpc_id
}

################################################################################
# Task Execution Role
################################################################################

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution.json
  # managed_policy_arns = local.task_execution_role_managed_policy_arn
  tags = local.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy_attachment" "execution" {
  count      = length(local.task_execution_role_managed_policy_arn)
  name       = "${local.name}-execution-policy"
  roles      = [aws_iam_role.execution.name]
  policy_arn = local.task_execution_role_managed_policy_arn[count.index]
}
