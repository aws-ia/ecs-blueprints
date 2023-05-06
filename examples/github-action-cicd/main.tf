provider "aws" {
  region = local.region
}

locals {
  name   = "gh-action-demo"
  region = "us-west-2"

  container_image = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
  container_name  = "gh-action-demo"

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
  version = "~> 5.0"

  name        = local.name
  cluster_arn = data.aws_ecs_cluster.core_infra.arn

  # These settings will be ignored after the initial create
  ignore_task_definition_changes = true
  desired_count                  = 3
  container_definitions = {
    default = {
      name  = local.container_name
      image = local.container_image
    }
  }

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}
