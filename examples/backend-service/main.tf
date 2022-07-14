provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name
}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.0"

  cluster_name = local.name

  tags = local.tags
}

module "service_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-service"
  description = "Security group for service"
  vpc_id      = module.vpc.vpc_id

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.tags
}

module "service" {
  source = "../../modules/ecs-service"

  name           = local.name
  desired_count  = 1
  ecs_cluster_id = module.ecs.cluster_id

  security_groups = [module.service_security_group.security_group_id]
  subnets         = module.vpc.private_subnets

  # Task Definition
  cpu                = 256
  memory             = 512
  image              = "public.ecr.aws/nginx/nginx:1.23-alpine-perl"
  task_role_policy   = data.aws_iam_policy_document.task_role.json
  execution_role_arn = data.aws_iam_role.ecs_core_infra_exec_role.arn

  tags = local.tags
}

# TODO: set a custom policy
data "aws_iam_policy_document" "task_role" {
  statement {
    actions   = ["ecs:DescribeClusters"]
    resources = [module.ecs.cluster_id]
  }
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
