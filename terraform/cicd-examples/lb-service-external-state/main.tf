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

# Terraform backend configuration to store state in S3
terraform {
  backend "s3" {}
}

locals {
  name   = "ecsdemo-frontend"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
    Environment = var.environment
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "service_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.3"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids

  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]
    }
  }

  http_tcp_listeners = [
    {
      port               = "80"
      protocol           = "HTTP"
      target_group_index = 0
    },
    {
      port               = "8080"
      protocol           = "HTTP"
      target_group_index = 1
    },
  ]

  target_groups = [
    {

      name             = "${local.name}-green-tg"
      backend_protocol = "HTTP"
      backend_port     = var.container_port
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = var.container_port
        matcher = "200-299"
      }
    },
    {
      name             = "${local.name}-blue-tg"
      backend_protocol = "HTTP"
      backend_port     = var.container_port
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = var.container_port
        matcher = "200-299"
      }
    },
  ]

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

module "ecs_service_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = local.name
  desired_count      = 3
  cluster_arn        = data.aws_ecs_cluster.core_infra.arn
  enable_autoscaling = false

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_alb_service = {
      type                     = "ingress"
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.service_alb.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  deployment_controller = {
    type = "CODE_DEPLOY"
  }

  load_balancer = [{
    container_name   = var.container_name
    container_port   = var.container_port
    target_group_arn = element(module.service_alb.target_group_arns, 0)
  }]

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  # service_connect_configuration = {
  #   enabled = false
  # }

  # Task Definition
  create_iam_role        = false
  create_task_exec_iam_role = true
  #task_exec_iam_role_arn = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command = true

  container_definitions = {
    main_container = {
      name                     = var.container_name
      image                    = var.container_image
      readonly_root_filesystem = false

      port_mappings = [{
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

resource "aws_sns_topic" "deployment_notificaitons" {
  name = "${var.environment}_${local.name}_deployment_topic"
}

module "deploy_dev_service" {
  source = "../../modules/codedeploy"
  name = "deploy_${var.environment}_${local.name}"
  ecs_cluster = data.aws_ecs_cluster.core_infra.cluster_name
  ecs_service = local.name
  sns_topic_arn = aws_sns_topic.deployment_notificaitons.arn
  iam_role_name = "deploy_${var.environment}_${local.name}"
  create_iam_role = true
  service_role = aws_iam_role.codedeploy_service_role.arn
  alb_listener = module.service_alb.http_tcp_listener_arns[0]
  tg_blue = "${local.name}-green-tg"
  tg_green = "${local.name}-blue-tg"
}

resource "aws_iam_role" "codedeploy_service_role" {
  name = "codedeploy-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_codedeploy_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codedeploy_service_role.name
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
  role       = aws_iam_role.codedeploy_service_role.name
}

################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
  
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-public-*"]
  }
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
  tags = {
    Environment = var.environment
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value

  tags = {
    Environment = var.environment
  }
}

data "aws_ecs_cluster" "core_infra" {
  tags = {
    Environment = var.environment
  }
  cluster_name = "core-infra"

}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"

  tags = {
    Environment = var.environment
  }
}
