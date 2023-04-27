provider "aws" {
  region = local.region
}

provider "sysdig" {
  sysdig_secure_api_token = var.sysdig_secure_api_token
}

locals {
  name   = "sysdig-infected-backend-demo"
  region = "us-west-2"

  container_image = "sysdiglabs/writer-to-bin"
  container_port  = 3000 # Container port is specific to this app example
  container_name  = "sysdig-backend-demo"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

# Sysdig Orchestrator Agent ECS Service Definition
module "sysdig_orchestrator_agent" {

  source = "sysdiglabs/fargate-orchestrator-agent/aws"

  name = "${local.name}-sysdig-orchestrator-agent"

  vpc_id           = data.aws_vpc.vpc.id
  subnets          = data.aws_subnets.private.ids
  collector_host   = var.sysdig_collector_url
  collector_port   = 6443
  access_key       = var.sysdig_access_key
  assign_public_ip = true # If using Internet Gateway
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

module "ecs_service_definition" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  deployment_controller = "ECS"

  name               = local.name
  desired_count      = 1
  cluster_arn        = data.aws_ecs_cluster.core_infra.arn
  enable_autoscaling = false

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_all_service = {
      type        = "ingress"
      from_port   = local.container_port
      to_port     = local.container_port
      protocol    = "tcp"
      description = "Service port"
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
  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  # Task Definition
  create_tasks_iam_role = true
  tasks_iam_role_statements = [
    {
      sid = "SysdigPolicy"
      actions = [
        "ecs:DescribeVolumes",
        "ecs:DescribeTags"
      ]
      resources = ["*"]
    },
    {
      sid = "ECSExec"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      resources = ["*"]
    }
  ]
  task_exec_iam_role_arn = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command = true

  cpu = 512

  container_definitions = {
    main_container = {
      name                     = local.container_name
      image                    = local.container_image
      cpu                      = 256
      readonly_root_filesystem = false
      entrypoint               = ["/opt/draios/bin/instrument"]
      command                  = ["/usr/bin/demo-writer-c", "/usr/bin/oh-no-i-wrote-in-bin"]
      linux_parameters = {
        capabilities = {
          add = ["SYS_PTRACE"]
        }
      }
      environment = [{
        name  = "SYSDIG_ORCHESTRATOR"
        value = module.sysdig_orchestrator_agent.orchestrator_host
        }, {
        name  = "SYSDIG_ORCHESTRATOR_PORT"
        value = module.sysdig_orchestrator_agent.orchestrator_port
        }, {
        name  = "SYSDIG_ACCESS_KEY"
        value = var.sysdig_access_key
        }, {
        name  = "SYSDIG_COLLECTOR"
        value = var.sysdig_collector_url
        }, {
        name  = "SYSDIG_COLLECTOR_PORT"
        value = 6443
        }, {
        name  = "SYSDIG_LOGGING"
        value = "debug"
      }],
      volumes_from = [{
        sourceContainer = "SysdigInstrumentation"
        readOnly        = true
      }]
    },
    sidecar_container = {
      name       = "SysdigInstrumentation"
      image      = "quay.io/sysdig/workload-agent:latest"
      cpu        = 256
      entrypoint = ["/opt/draios/bin/logwriter"]
    }
  }

  tags = local.tags
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
  name_regex = "core-infra-*"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
