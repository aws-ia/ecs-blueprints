provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

locals {
  name   = var.service_name
  region = var.region
  k8s_objs = {"k8s_service":var.service_name, "k8s_deployment":var.deployment_name, "k8s_service_type":var.service_type}
  tags = merge(var.label_selector, var.deployment_tags, var.task_tags, local.k8s_objs)
}

################################################################################
# ECS Blueprint
################################################################################

module "service_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"
  name        = "${local.name}-alb-sg"
  description = "Security group for client application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]

  tags = local.tags
}

module "service_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"
  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.service_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = var.listener_port
      protocol           = var.listener_protocol
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tg"
      backend_protocol = "HTTP"
      backend_port     = var.lb_container_port
      target_type      = "ip"
      health_check = {
        path    = var.lb_health_check_path
        port    = var.lb_container_port
        matcher = var.lb_health_check_matcher_codes
      }
    },
  ]

  tags = local.tags
}

module "service_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-task-sg"
  description = "Security group for service task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      from_port                = var.lb_container_port
      to_port                  = var.lb_container_port
      protocol                 = "tcp"
      source_security_group_id = module.service_alb_security_group.security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}


resource "aws_service_discovery_service" "sd_service" {
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
    failure_threshold = 1
  }
}

module "ecs_service_definition" {
  source = "../../modules/ecs-service"

  name           = local.name
  desired_count  = 3
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  load_balancers = [{
    target_group_arn = element(module.service_alb.target_group_arns, 0)
  }]

  service_registry_list = [{
    registry_arn = aws_service_discovery_service.sd_service.arn
  }]

  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy = false
  lb_container_port       = var.lb_container_port
  lb_container_name       = var.lb_container_name
  execution_role_arn      = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command  = true

  container_definitions = var.containers
  container_definition_defaults = {"readonly_root_filesystem":false}

  tags = local.tags
}

################################################################################
# SSM Parameters
################################################################################

resource "aws_ssm_parameter" "task_container_env_parameters" {
  count = length(var.ssm_parameters)
  name  = var.ssm_parameters[count.index]["name"]
  type  = "String"
  value = var.ssm_parameters[count.index]["value"]
}

resource "aws_ssm_parameter" "task_container_env_secrets" {
  count = length(var.ssm_secrets)
  name  = var.ssm_parameters[count.index]["name"]
  type  = "SecureString"
  value = base64decode(var.ssm_secrets[count.index]["value"])
}

################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.ecs_cluster_name]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["${var.ecs_cluster_name}-public-*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.ecs_cluster_name}-private-*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name
}

data "aws_iam_roles" "ecs_core_infra_exec_role" {
  name_regex = "${var.ecs_cluster_name}-execution-*"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "${var.service_namespace}.${var.ecs_cluster_name}.local"
  type = "DNS_PRIVATE"
}
