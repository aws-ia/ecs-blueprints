provider "aws" {
  region = "us-west-2"
}

locals {
  name = "otel-collector-test"

  container_port = 8080 # Container port is specific to this app example
  container_name = "prometheus-sample-app"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
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
  desired_count  = 1
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  service_registry_list = [{
    registry_arn = aws_service_discovery_service.sd_service.arn
  }]
  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy = true
  lb_container_port       = local.container_port
  lb_container_name       = local.container_name
  task_role_policy        = data.aws_iam_policy_document.task_role.json
  execution_role_arn      = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command  = true

  container_definitions = {
    main_container = {
      name                     = local.container_name
      image                    = "public.ecr.aws/aws-otel-test/prometheus-sample-app:latest"
      readonly_root_filesystem = false
      port_mappings = [{
        protocol : "tcp",
        containerPort : local.container_port
        hostPort : local.container_port
      }]
    },
    sidecar_container = {
      name        = "aws-otel-collector",
      image       = "public.ecr.aws/aws-observability/aws-otel-collector:v0.21.1",
      secrets     = [{ name = "AOT_CONFIG_CONTENT", valueFrom = "otel-collector-config" }],
      environment = [{ name = "PROMETHEUS_SAMPLE_APP", value = "prometheus-sample-app:8080" }]
    }
  }
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
  name  = "otel-collector-config"
  type  = "String"
  value = file("./ecs-adot-config.yaml")
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

data "aws_iam_roles" "ecs_core_infra_exec_role" {
  name_regex = "core-infra-execution-*"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
