provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name     = var.name
  vpc_cidr = "10.94.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  container_port = 3000

  # Tasks in this VPC have no path to the internet, so they cannot pull from
  # public.ecr.aws directly (public ECR is not reachable through the ECR
  # interface endpoints). Instead they pull the image from a private ECR
  # pull-through cache repository: the task only talks to private ECR through
  # the ecr.api/ecr.dkr/S3 endpoints, and the ECR service fetches the upstream
  # public image on its side.
  upstream_image = "aws-containers/ecsdemo-nodejs"
  image_tag      = "c3e96da"
  cached_image   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name}/${local.upstream_image}:${local.image_tag}"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# VPC without internet access
################################################################################

# No internet gateway, no NAT gateway, no public subnets: every AWS API the
# tasks need is reached through the VPC endpoints below.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]

  enable_nat_gateway = false

  tags = local.tags
}

################################################################################
# VPC Endpoints
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.1"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_security_group      = true
  security_group_name_prefix = "${local.name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = merge({
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name = "${local.name}-s3"
      }
    }
    },
    # ssmmessages is required by ECS Exec, the validation path into tasks that
    # have no load balancer and no internet route.
    { for service in toset(["ecr.api", "ecr.dkr", "ecs", "ecs-telemetry", "ecs-agent", "sqs", "logs", "ssm", "ssmmessages", "secretsmanager"]) :
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
# ECR pull-through cache for the public demo image
################################################################################

resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  ecr_repository_prefix = local.name
  upstream_registry_url = "public.ecr.aws"
}

# Pre-created so the task execution role only needs ecr:BatchImportUpstreamImage
# (not ecr:CreateRepository) for the first pull to populate the cache.
resource "aws_ecr_repository" "cached_demo_image" {
  name         = "${local.name}/${local.upstream_image}"
  force_delete = true

  tags = local.tags

  depends_on = [aws_ecr_pull_through_cache_rule.public_ecr]
}

################################################################################
# ECS cluster and demo service
################################################################################

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

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = local.name
  desired_count = 2
  cluster_arn   = module.ecs_cluster.arn

  # Block `terraform apply` until tasks reach a steady state. Because this pattern has no
  # internet egress, a broken endpoint or pull-through-cache misconfiguration surfaces as
  # tasks that never start; waiting here turns that into a clear apply failure instead of
  # a green apply hiding a crash-looping service.
  wait_for_steady_state = true

  enable_execute_command = true

  # Allows the first pull to import the upstream public image into the
  # pull-through cache repository.
  task_exec_iam_statements = [
    {
      sid       = "ECRPullThroughCacheImport"
      actions   = ["ecr:BatchImportUpstreamImage"]
      resources = [aws_ecr_repository.cached_demo_image.arn]
    }
  ]

  container_definitions = {
    backend = {
      image                  = local.cached_image
      readonlyRootFilesystem = false

      portMappings = [{
        name          = "backend"
        protocol      = "tcp"
        containerPort = local.container_port
      }]
    }
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    vpc_clients = {
      from_port   = local.container_port
      to_port     = local.container_port
      ip_protocol = "tcp"
      description = "Demo app clients within this VPC"
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
