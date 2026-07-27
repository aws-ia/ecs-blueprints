provider "aws" {
  region = "us-west-2"
}

locals {
  name = "core-infra"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# VPC Endpoints Module
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = data.aws_subnets.private.ids

  create_security_group      = true
  security_group_name_prefix = "${local.name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [data.aws_vpc.vpc.cidr_block]
    }
  }

  endpoints = merge({
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = [data.aws_route_table.private.id]
      tags = {
        Name = "${local.name}-s3"
      }
    }
    },
    { for service in toset(["ecr.api", "ecr.dkr", "ecs", "ecs-telemetry", "ecs-agent", "sqs", "logs", "ssm", "secretsmanager"]) :
      replace(service, ".", "_") =>
      {
        service             = service
        private_dns_enabled = true
        tags                = { Name = "${local.name}-${service}" }
      }
  })

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_route_table" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private"]
  }
}
