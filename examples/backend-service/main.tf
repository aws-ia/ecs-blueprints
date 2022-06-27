provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

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

module "ecr" {
  source = "../../modules/ecr"

  name = local.name
  tags = local.tags
}

module "cluster" {
  source = "../../modules/ecs/cluster"

  name = local.name
  tags = local.tags
}

resource "aws_security_group" "allow_all_egress" {
  name        = local.name
  description = "Allow access to all external resources"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
}

resource "aws_security_group_rule" "allow_all_egress" {
  security_group_id = aws_security_group.allow_all_egress.id
  description       = "Allows task to establish connections to all external resources"
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

module "service" {
  source = "../../modules/ecs/service"

  name            = local.name
  ecs_cluster_id  = local.name
  task_definition = module.task_definition.task_definition_arn
  desired_count   = var.desired_count
  subnets         = module.vpc.private_subnets
  security_groups = [aws_security_group.allow_all_egress.id]

  tags = local.tags
}

module "task_definition" {
  source = "../../modules/ecs/task-definition"

  name                 = local.name
  region               = local.region
  cpu                  = var.cpu
  memory               = var.memory
  image                = var.image
  execution_role       = module.roles.execution_role
  task_role            = module.roles.task_role
  cloudwatch_log_group = aws_cloudwatch_log_group.main.name
}

# TODO: set a custom policy
data "aws_iam_policy_document" "task_role" {
  statement {
    actions   = ["ecs:DescribeClusters"]
    resources = [module.cluster.id]
  }
}

module "roles" {
  source = "../../modules/ecs/roles"

  name             = local.name
  task_role_policy = data.aws_iam_policy_document.task_role.json
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/service/${local.name}"
  retention_in_days = var.logs_retention_in_days
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
