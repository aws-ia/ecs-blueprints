# STATE_BUCKET=$(aws ssm get-parameters --names terraform_state_bucket | jq -r '.Parameters[0].Value')

# terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=lb-service-dev.tfstate" -backend-config="region=us-west-2"
# terraform apply -var-file=../dev.tfvars
# terraform destroy -var-file=../dev.tfvars

# terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=lb-service-qa.tfstate" -backend-config="region=us-west-2"
# terraform apply -var-file=../qa.tfvars
# terraform destroy -var-file=../qa.tfvars

provider "aws" {
  region = var.region
}

# Terraform backend configuration to store state in S3.
# S3 native state locking (use_lockfile) requires Terraform >= 1.11.
terraform {
  backend "s3" {
    use_lockfile = true
  }
}

locals {
  name = "ecsdemo-frontend"

  tags = {
    Blueprint   = local.name
    GithubRepo  = "github.com/aws-ia/ecs-blueprints"
    Environment = var.environment
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "service_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids

  enable_deletion_protection = false

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    service = {
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.vpc.cidr_block
    }
  }

  listeners = {
    production = {
      port     = 80
      protocol = "HTTP"

      # The blue target group receives production traffic initially; CodeDeploy
      # shifts the listener between blue and green on each deployment.
      forward = {
        target_group_key = "blue"
      }
    }
  }

  target_groups = {
    blue = {
      name              = "${local.name}-blue-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      health_check = {
        path    = "/"
        port    = var.container_port
        matcher = "200-299"
      }
    }
    green = {
      name              = "${local.name}-green-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      health_check = {
        path    = "/"
        port    = var.container_port
        matcher = "200-299"
      }
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
  }
}

module "ecs_service_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = local.name
  desired_count                       = 3
  cluster_arn                         = data.aws_ecs_cluster.core_infra.arn
  enable_autoscaling                  = false

  subnet_ids = data.aws_subnets.private.ids
  security_group_ingress_rules = {
    ingress_alb_service = {
      from_port                    = var.container_port
      to_port                      = var.container_port
      ip_protocol                  = "tcp"
      description                  = "Service port"
      referenced_security_group_id = module.service_alb.security_group_id
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  deployment_controller = {
    type = "CODE_DEPLOY"
  }

  load_balancer = {
    service = {
      container_name = var.container_name
      container_port = var.container_port
      # The service starts on the blue target group, matching the listener's
      # initial forward. CodeDeploy alternates task sets between blue and green.
      target_group_arn = module.service_alb.target_groups["blue"].arn
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  # service_connect_configuration = {
  #   enabled = false
  # }

  # Task Definition
  create_iam_role           = false
  create_task_exec_iam_role = var.task_execution_role_arn == null
  task_exec_iam_role_arn    = var.task_execution_role_arn
  create_tasks_iam_role     = var.task_role_arn == null
  tasks_iam_role_arn        = var.task_role_arn
  enable_execute_command    = true

  container_definitions = {
    main_container = {
      name                   = var.container_name
      image                  = var.container_image
      readonlyRootFilesystem = false

      portMappings = [{
        protocol : "tcp",
        containerPort : var.container_port
        hostPort : var.container_port
      }]
    }
  }

  ignore_task_definition_changes = false

  tags = local.tags
}

################################################################################
# Code Deploy
################################################################################

resource "aws_sns_topic" "deployment_notifications" {
  name = "${var.environment}_${local.name}_deployment_topic"
}

module "deploy_dev_service" {
  source          = "../../modules/codedeploy"
  name            = "deploy_${var.environment}_${local.name}"
  ecs_cluster     = data.aws_ecs_cluster.core_infra.cluster_name
  ecs_service     = local.name
  sns_topic_arn   = aws_sns_topic.deployment_notifications.arn
  iam_role_name   = "deploy_${var.environment}_${local.name}"
  create_iam_role = var.codedeploy_service_role_arn == null
  service_role    = var.codedeploy_service_role_arn
  alb_listener    = module.service_alb.listeners["production"].arn
  # tg_blue is the first target group in the CodeDeploy deployment group and
  # must be the one the listener initially forwards production traffic to
  # (blue, above); tg_green receives the replacement task set on deployment.
  tg_blue  = "${local.name}-blue-tg"
  tg_green = "${local.name}-green-tg"
}

################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-external-state"]
  }

  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-external-state-public-*"]
  }
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-external-state-private-*"]
  }
  tags = {
    Environment = var.environment
  }
}

data "aws_ecs_cluster" "core_infra" {
  tags = {
    Environment = var.environment
  }
  cluster_name = "core-infra-external-state"

}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"

  tags = {
    Environment = var.environment
  }
}
