
# STATE_BUCKET=$(aws ssm get-parameters --names terraform_state_bucket | jq -r '.Parameters[0].Value')

# terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=core-infra-dev.tfstate" -backend-config="region=us-west-2"
# terraform apply -var-file=../dev.tfvars
# terraform destroy -var-file=../dev.tfvars

# terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=core-infra-qa.tfstate" -backend-config="region=us-west-2"
# terraform apply -var-file=../qa.tfvars
# terraform destroy -var-file=../qa.tfvars

provider "aws" {
  region = var.region
}

# Terraform backend configuration to store state in S3
terraform {
  backend "s3" {}
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name     = basename(path.cwd)
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint   = local.name
    GithubRepo  = "github.com/aws-ia/ecs-blueprints"
    Environment = var.environment
  }
}

################################################################################
# ECS Blueprint
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
  create_task_exec_iam_role = false
  # Allow read access to all SSM params in current account for demo
  task_exec_ssm_param_arns = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  # Allow read access to all secrets in current account for demo
  task_exec_secret_arns = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:*"]

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

################################################################################
# Service discovery namespaces
################################################################################

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "default.${local.name}.local"
  description = "Service discovery namespace.clustername.local"
  vpc         = module.vpc.vpc_id

  tags = local.tags
}
