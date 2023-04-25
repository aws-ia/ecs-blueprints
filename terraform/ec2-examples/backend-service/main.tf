provider "aws" {
  region = local.region
}

locals {
  name   = "ecsdemo-backend"
  region = "us-west-2"

  container_image = "public.ecr.aws/aws-containers/ecsdemo-nodejs:c3e96da"
  container_port  = 3000 # Container port is specific to this app example
  container_name  = "ecsdemo-nodejs"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

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
  source = "github.com/clowdhaus/terraform-aws-ecs//modules/service"

  deployment_controller = "ECS"

  name               = local.name
  desired_count      = 3
  cluster_arn        = data.aws_ecs_cluster.core_infra.arn
  enable_autoscaling = false
  # cpu                = 1024
  # memory             = 4096

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

  # service_connect_configuration = {
  #   enabled = false
  #   service = {
  #     client_alias = [{
  #       port     = local.container_port
  #       dns_name = local.container_name
  #     }],
  #     port_name      = "${local.container_name}-${local.container_port}"
  #     discovery_name = local.container_name
  #   }
  # }

  # Task Definition
  requires_compatibilities = ["EC2", "FARGATE"]
  launch_type              = "EC2"
  create_iam_role          = false
  task_exec_iam_role_arn   = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command   = true

  #https://docs.aws.amazon.com/AmazonECS/latest/developerguide/example_task_definitions.html
  container_definitions = {
    fluent-bit = {
      # cpu       = 512
      # memory    = 1024
      essential = true
      image     = nonsensitive(data.aws_ssm_parameter.fluentbit.value)
      firelens_configuration = {
        type = "fluentbit"
      }
      memory_reservation = 50
    }

    main_container = {
      name      = local.container_name
      image     = local.container_image
      essential = true
      # cpu       = 512
      # memory    = 1024
      port_mappings = [{
        name : "${local.container_name}-${local.container_port}"
        protocol : "tcp",
        containerPort : local.container_port
        hostPort : local.container_port
      }]

      dependencies = [{
        containerName = "fluent-bit"
        condition     = "START"
      }]

      enable_cloudwatch_logging = false
      log_configuration = {
        logDriver = "awsfirelens"
        options = {
          Name                    = "firehose"
          region                  = local.region
          delivery_stream         = "my-stream"
          log-driver-buffer-limit = "2097152"
        }
      }
      memory_reservation = 100

    }
  }

  ignore_task_definition_changes = false

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

data "aws_iam_roles" "ecs_core_infra_exec_role" {
  name_regex = "core-infra-execution*"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}

data "aws_ssm_parameter" "fluentbit" {
  name = "/aws/service/aws-for-fluent-bit/stable"
}
