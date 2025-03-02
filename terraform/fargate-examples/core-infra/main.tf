provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

# Data Source to get the default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

locals {
  name   = "core-infra"
  region = "eu-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  default_vpc_id         = data.aws_vpc.default.id
  default_vpc_cidr_block = data.aws_vpc.default.cidr_block

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/berrymat/ecs-blueprints"
  }
}

################################################################################
# Container Security Group
################################################################################
resource "aws_security_group" "fargate_containers" {
  name        = "${local.name}-fargate-containers"
  description = "Security group for Fargate containers"
  vpc_id      = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "fargate_containers_ingress_sql" {
  type              = "ingress"
  from_port         = 1433
  to_port           = 1433
  protocol          = "tcp"
  cidr_blocks       = [local.default_vpc_cidr_block] # Default VPC
  security_group_id = aws_security_group.fargate_containers.id
}

resource "aws_security_group_rule" "fargate_containers_ingress_mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [local.default_vpc_cidr_block] # Default VPC
  security_group_id = aws_security_group.fargate_containers.id
}

#Add other ingress rules here

# Add egress rule to allow all outbound
resource "aws_security_group_rule" "fargate_containers_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # all
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.fargate_containers.id
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.6"

  cluster_name = local.name

  cluster_service_connect_defaults = {
    namespace = aws_service_discovery_private_dns_namespace.this.arn
  }

  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  tags = local.tags
}

################################################################################
# Service Discovery
################################################################################

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "default.${local.name}.local"
  description = "Service discovery <namespace>.<clustername>.local"
  vpc         = module.vpc.vpc_id

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true

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
# VPC Peering
################################################################################
# Create Peering Connection
resource "aws_vpc_peering_connection" "default_to_new" {
  peer_vpc_id = local.default_vpc_id
  vpc_id      = module.vpc.vpc_id
  auto_accept = true
}

# Update the Route table in the default VPC
resource "aws_route" "default_to_new" {
  route_table_id            = data.aws_route_table.default.id
  destination_cidr_block    = local.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.default_to_new.id
}

# Update the route table in the new VPC
resource "aws_route" "new_to_default" {
  route_table_id            = module.vpc.default_route_table_id
  destination_cidr_block    = local.default_vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default_to_new.id
}

# Get the list of subnets
data "aws_subnet" "private_subnets" {
  for_each = { for i, subnet_id in module.vpc.private_subnets : local.azs[i] => subnet_id }
  id       = each.value
}
