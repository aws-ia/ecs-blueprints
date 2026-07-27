provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name        = var.name
  namespace   = "${var.name}.local"
  vpc_cidr    = "10.91.0.0/16"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  server_port = 3000

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# Self-contained infrastructure
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = local.name

  setting = [{
    name  = "containerInsights"
    value = "enhanced"
  }]

  tags = local.tags
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = local.namespace
  vpc  = module.vpc.vpc_id
  tags = local.tags
}

resource "aws_service_discovery_service" "this" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {}
}

################################################################################
# Private backend service
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name                   = local.name
  desired_count          = 3
  cluster_arn            = module.ecs_cluster.arn
  enable_autoscaling     = false
  enable_execute_command = true

  container_definitions = {
    backend = {
      image                  = "public.ecr.aws/aws-containers/ecsdemo-nodejs:c3e96da"
      readonlyRootFilesystem = false

      portMappings = [{
        name          = "backend"
        protocol      = "tcp"
        containerPort = local.server_port
      }]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    vpc_clients = {
      from_port   = local.server_port
      to_port     = local.server_port
      ip_protocol = "tcp"
      description = "Backend clients within this VPC"
      cidr_ipv4   = local.vpc_cidr
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags
}
