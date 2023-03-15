provider "aws" {
  region = var.aws_region
}

provider "sysdig" {
  sysdig_secure_api_token = var.sysdig_secure_api_token
}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name = var.service_name

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
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
      from_port   = var.container_port
      to_port     = var.container_port
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

# Sysdig Orchestrator Agent ECS Service Definition
module "sysdig_orchestrator_agent" {

  source = "sysdiglabs/fargate-orchestrator-agent/aws"

  name = "${local.name}-sysdig-orchestrator-agent"

  vpc_id           = data.aws_vpc.vpc.id
  subnets          = data.aws_subnets.private.ids
  collector_host   = var.sysdig_collector_url
  collector_port   = var.sysdig_collector_port
  access_key       = var.sysdig_access_key
  assign_public_ip = true # If using Internet Gateway
}

# ECS Service Definition for the instrumented
module "ecs_service_definition" {

  source = "../../modules/ecs-service"

  name                       = var.service_name
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
  attach_task_role_policy = true
  lb_container_port       = var.container_port
  lb_container_name       = var.container_name
  cpu                     = var.cpu
  memory                  = var.memory
  task_role_policy        = data.aws_iam_policy_document.task_role.json
  execution_role_arn      = data.aws_iam_role.ecs_core_infra_exec_role.arn
  enable_execute_command  = true

  container_definition_defaults = var.container_definition_defaults

  container_definitions = {
    main_container = {
      image                    = var.container_image
      name                     = var.container_name
      readonly_root_filesystem = false
      entrypoint               = ["/opt/draios/bin/instrument"]
      command                  = var.container_command
      linux_parameters = {
        capabilities = {
          add = ["SYS_PTRACE"]
        }
      }
      environment = [
        {
          name  = "SYSDIG_ORCHESTRATOR"
          value = module.sysdig_orchestrator_agent.orchestrator_host
        },
        {
          name  = "SYSDIG_ORCHESTRATOR_PORT"
          value = module.sysdig_orchestrator_agent.orchestrator_port
        },
        {
          name  = "SYSDIG_ACCESS_KEY"
          value = var.sysdig_access_key
        },
        {
          name  = "SYSDIG_COLLECTOR"
          value = var.sysdig_collector_url
        },
        {
          name  = "SYSDIG_COLLECTOR_PORT"
          value = var.sysdig_collector_port
        },
        {
          name  = "SYSDIG_LOGGING"
          value = "debug"
        }
      ],
      volumes_from = [
        {
          sourceContainer = "SysdigInstrumentation"
          readOnly        = true
        }
      ]
    },
    sidecar_container = var.sidecar_container_definition
  }

  tags = local.tags
}

################################################################################
# Task IAM Role Policy
################################################################################

data "aws_iam_policy_document" "task_role" {
  statement {
    sid = "SysdigPolicy"
    actions = [
      "ecs:DescribeVolumes",
      "ecs:DescribeTags"
    ]
    resources = ["*"]
  }
}
