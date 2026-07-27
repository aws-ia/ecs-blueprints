provider "aws" {
  region = "us-west-2"
}

locals {
  name = "otel-collector-test"

  container_port = 8080 # Container port is specific to this app example

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
  version = "~> 5.6"

  name          = local.name
  desired_count = 1
  cluster_arn   = data.aws_ecs_cluster.core_infra.arn

  # Task Definition
  enable_execute_command = true
  tasks_iam_role_policies = {
    ADOT = aws_iam_policy.adot.arn
  }

  container_definitions = {
    prometheus-sample-app = {
      image                    = "public.ecr.aws/aws-otel-test/prometheus-sample-app:latest"
      cpu                      = 256
      readonly_root_filesystem = false
      port_mappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    },
    aws-otel-collector = {
      image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.21.1",
      cpu   = 256
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT"
          valueFrom = "otel-collector-config"
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

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_user_service = {
      type        = "ingress"
      from_port   = 0
      to_port     = 10000
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = ["0.0.0.0/0"]
    }
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
    failure_threshold = 1
  }
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
    resources = ["*"]
  }
}

################################################################################
# SSM Parameter Store for ADOT Config YAML
################################################################################

resource "aws_ssm_parameter" "adot_config_ssm_parameter" {
  name  = "otel-collector-config"
  type  = "String"
  value = file("./ecs-adot-config.yaml")
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

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
