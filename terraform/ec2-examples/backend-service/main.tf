provider "aws" {
  region = local.region
}

locals {
  name   = "ecsdemo-backend"
  region = "us-west-2"

  container_image = "public.ecr.aws/aws-containers/ecsdemo-nodejs:c3e96da"
  container_port  = 3000 # Container port is specific to this app example

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = local.name
  desired_count                       = 3
  cluster_arn                         = data.aws_ecs_cluster.core_infra.arn
  enable_autoscaling                  = false

  # Task Definition
  enable_execute_command   = true
  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = "core-infra" # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  container_definitions = {
    ecsdemo-nodejs = {
      image                  = local.container_image
      readonlyRootFilesystem = false
      portMappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  subnet_ids = data.aws_subnets.private.ids
  security_group_ingress_rules = {
    ingress_all_service = {
      from_port   = local.container_port
      to_port     = local.container_port
      ip_protocol = "tcp"
      description = "Service port"
      cidr_ipv4   = data.aws_vpc.vpc.cidr_block
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags
}

resource "aws_service_discovery_service" "this" {
  name = local.name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
  }
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

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
