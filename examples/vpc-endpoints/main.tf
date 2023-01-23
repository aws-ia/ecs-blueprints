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
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = data.aws_subnets.private.ids

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = [data.aws_route_table.private.id]

      tags = { Name = "${local.name}-s3" }
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ecr-api" }
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ecr-dkr" }
    },
    ecs = {
      service             = "ecs"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ecs" }
    },
    ecs_telemetry = {
      create              = true
      service             = "ecs-telemetry"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ecs-telemetry" }
    },
    ecs_agent = {
      service             = "ecs-agent"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ecs-agent" }
    },
    cloudwatch = {
      service             = "logs"
      private_dns_enabled = true

      tags = { Name = "${local.name}-cw-logs" }
    },
    ssm = {
      service             = "ssm"
      private_dns_enabled = true

      tags = { Name = "${local.name}-ssm" }
    },
    secrets_manager = {
      service             = "secretsmanager"
      private_dns_enabled = true

      tags = { Name = "${local.name}-secrets-manager" }
    },
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name}-vpc_endpints"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]
  }

  tags = local.tags
}

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

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_route_table" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private"]
  }
}
