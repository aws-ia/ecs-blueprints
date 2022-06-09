# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

module "vpc" {
  source     = "aws-ia/vpc/aws"
  version    = ">= 1.0.0"
  name       = var.namespace
  cidr_block = "10.0.0.0/20"
  az_count   = 3
  tags       = var.tags
  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
    }
    private = {
      netmask      = 24
      route_to_nat = true
    }
  }
}

locals {
  # extract the subnet list from the vpc module
  private_subnet_ids = [for _, value in module.vpc.private_subnet_attributes_by_az : value.id]
}

module "ecr" {
  source = "../../modules/ecr"
  name   = var.namespace
  tags   = var.tags
}

module "cluster" {
  source = "../../modules/ecs/cluster"
  name   = var.namespace
  tags   = var.tags
}

resource "aws_security_group" "allow_all_egress" {
  name        = var.namespace
  description = "Allow access to all external resources"
  vpc_id      = module.vpc.vpc_attributes.id
  tags        = var.tags
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
  source          = "../../modules/ecs/service"
  name            = var.namespace
  ecs_cluster_id  = var.namespace
  task_definition = module.task_definition.task_definition_arn
  desired_count   = var.desired_count
  tags            = var.tags
  subnets         = local.private_subnet_ids
  security_groups = [aws_security_group.allow_all_egress.id]
}

module "task_definition" {
  source               = "../../modules/ecs/task-definition"
  name                 = var.namespace
  region               = var.region
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
  source           = "../../modules/ecs/roles"
  name             = var.namespace
  task_role_policy = data.aws_iam_policy_document.task_role.json
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/service/${var.namespace}"
  retention_in_days = var.logs_retention_in_days
}
