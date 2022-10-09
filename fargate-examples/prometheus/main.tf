provider "aws" {
  region = var.aws_region
}

# data "aws_caller_identity" "current" {}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name = var.service_name

  tags = {
    Blueprint = local.name
  }

  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value == "" ? "${var.core_stack_name}-private-" : var.private_subnets_tag_value
}

################################################################################
# Data Sources from ecs-blueprint-infra
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = [local.tag_val_vpc]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_private_subnet}*"]
  }
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
}

data "aws_service_discovery_dns_namespace" "sd_namespace" {
  name = "${var.namespace}.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}

################################################################################
# ECS Blueprint
################################################################################


module "service_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-task-sg"
  description = "Security group for service task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  egress_rules        = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 10000
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = local.tags
}

resource "aws_service_discovery_service" "sd_service" {
  name = local.name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.sd_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

module "ecs_service_definition" {
  source = "../../modules/ecs-service"

  name                       = local.name
  desired_count              = var.desired_count
  ecs_cluster_id             = data.aws_ecs_cluster.core_infra.cluster_name
  cp_strategy_base           = var.cp_strategy_base
  cp_strategy_fg_weight      = var.cp_strategy_fg_weight
  cp_strategy_fg_spot_weight = var.cp_strategy_fg_spot_weight

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  service_registry_list = [{
    registry_arn = aws_service_discovery_service.sd_service.arn
  }]
  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy       = true
  container_name                = var.container_name
  container_port                = var.container_port
  cpu                           = var.task_cpu
  memory                        = var.task_memory
  image                         = var.container_image
  task_role_policy              = data.aws_iam_policy_document.task_role.json
  execution_role_arn            = data.aws_iam_role.ecs_core_infra_exec_role.arn
  sidecar_container_definitions = var.sidecar_container_definitions
  enable_execute_command        = true
  tags                          = local.tags
}

################################################################################
# Task IAM Role Policy
################################################################################

data "aws_iam_policy_document" "task_role" {
  statement {
    sid = "OTELPolicy"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "ssm:GetParameters"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AMPRemoteWrite"
    actions   = ["aps:RemoteWrite"]
    resources = ["*"]
  }
}

################################################################################
# SSM Paramter Store for ADOT Config YAML
################################################################################

resource "aws_ssm_parameter" "adot_config_ssm_parameter" {
  name  = var.adot_config_ssm_parameter
  type  = "String"
  value = file("./ecs-adot-config.yaml")
}
