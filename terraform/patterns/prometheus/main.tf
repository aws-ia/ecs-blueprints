provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name      = var.name
  namespace = "${var.name}.local"
  vpc_cidr  = "10.93.0.0/16"
  azs       = slice(data.aws_availability_zones.available.names, 0, 2)

  container_port = 8080 # Container port is specific to this app example

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
  name = local.name

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
# Amazon Managed Service for Prometheus
################################################################################

resource "aws_prometheus_workspace" "this" {
  alias = local.name

  tags = local.tags
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name          = local.name
  desired_count = 1
  cluster_arn   = module.ecs_cluster.arn

  # Block apply until the task is stable so a broken image or ADOT config surfaces as an
  # apply failure rather than a green apply hiding a crash-looping collector.
  wait_for_steady_state = true

  # Task Definition
  enable_execute_command = true
  tasks_iam_role_policies = {
    ADOT = aws_iam_policy.adot.arn
  }
  task_exec_ssm_param_arns = [aws_ssm_parameter.adot_config.arn]

  container_definitions = {
    prometheus-sample-app = {
      # Pinned by digest (2026-07-26) because the upstream repository only
      # publishes a `latest` tag; the digest keeps deploys deterministic.
      # Refresh with: docker manifest inspect public.ecr.aws/aws-otel-test/prometheus-sample-app:latest
      image                  = "public.ecr.aws/aws-otel-test/prometheus-sample-app@sha256:eb001cd40963ec64ee7d2988f128a36606b0b021cc7e4d9df2f20853452eacc4"
      cpu                    = 256
      readonlyRootFilesystem = false
      portMappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    },
    aws-otel-collector = {
      image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.49.0",
      cpu   = 256
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT"
          valueFrom = aws_ssm_parameter.adot_config.arn
        }
      ]
      environment = [
        {
          name  = "PROMETHEUS_SAMPLE_APP"
          value = "prometheus-sample-app:${local.container_port}"
        }
      ]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  security_group_ingress_rules = {
    ingress_vpc_app_port = {
      from_port   = local.container_port
      to_port     = local.container_port
      ip_protocol = "tcp"
      description = "Sample app port from within the VPC"
      cidr_ipv4   = local.vpc_cidr
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

################################################################################
# ADOT IAM Policy
################################################################################

resource "aws_iam_policy" "adot" {
  name_prefix = "${local.name}-adot"
  description = "ADOT IAM permissions"
  policy      = data.aws_iam_policy_document.adot.json

  tags = local.tags
}

data "aws_iam_policy_document" "adot" {
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
    resources = [aws_prometheus_workspace.this.arn]
  }
}

################################################################################
# SSM Parameter Store for ADOT Config YAML
################################################################################

resource "aws_ssm_parameter" "adot_config" {
  # Prefixed with var.name so two copies of this pattern in one account and
  # Region do not collide. The task execution role permission
  # (task_exec_ssm_param_arns) and the collector secret (valueFrom) both
  # reference this resource, so all three stay in lockstep.
  name = "${local.name}-otel-collector-config"
  type = "String"
  value = templatefile("${path.module}/ecs-adot-config.yaml.tftpl", {
    amp_remote_write_endpoint = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
    aws_region                = var.aws_region
  })

  tags = local.tags
}
