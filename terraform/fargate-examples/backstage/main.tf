provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "unicorn-ui"
  region = var.aws_region

  container_port = 7007 # Container port is specific to this app example
  container_name = "unicorn-ui"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = local.name
  desired_count                       = 3
  cluster_arn                         = data.aws_ecs_cluster.core_infra.arn

  # Task Definition
  enable_execute_command = true
  task_exec_secret_arns = [
    data.aws_secretsmanager_secret.github_token.arn,
    module.aurora_postgresdb.cluster_master_user_secret[0].secret_arn,
  ]

  container_definitions = {
    (local.container_name) = {
      image                  = module.ecr.repository_url
      readonlyRootFilesystem = false

      environment = [
        { name = "BASE_URL", value = "http://${module.alb.dns_name}" },
        { name = "POSTGRES_HOST", value = module.aurora_postgresdb.cluster_endpoint },
        { name = "POSTGRES_PORT", value = module.aurora_postgresdb.cluster_port },
        { name = "POSTGRES_USER", value = "postgres" },
      ]

      secrets = [
        { name = "GITHUB_TOKEN", valueFrom = data.aws_secretsmanager_secret.github_token.arn },
        { name = "POSTGRES_PASSWORD", valueFrom = "${module.aurora_postgresdb.cluster_master_user_secret[0].secret_arn}:password::" }
      ]

      portMappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["ecs-task"].arn
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids = data.aws_subnets.private.ids
  security_group_ingress_rules = {
    ingress_alb_service = {
      from_port                    = local.container_port
      to_port                      = local.container_port
      ip_protocol                  = "tcp"
      description                  = "Service port"
      referenced_security_group_id = module.alb.security_group_id
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

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = local.name

  # For example only
  enable_deletion_protection = false

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = { for subnet in data.aws_subnet.private_cidr :
    (subnet.availability_zone) => {
      ip_protocol = "-1"
      cidr_ipv4   = subnet.cidr_block
    }
  }

  listeners = {
    http = {
      port     = "80"
      protocol = "HTTP"

      forward = {
        target_group_key = "ecs-task"
      }
    }
  }

  target_groups = {
    ecs-task = {
      protocol    = "HTTP"
      port        = local.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200-299"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }

  tags = local.tags
}

################################################################################
# RDS Aurora for Backstage backend db
################################################################################

module "aurora_postgresdb" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.5"

  name        = "backstage-db"
  engine      = "aurora-postgresql"
  engine_mode = "provisioned"

  vpc_id                 = data.aws_vpc.vpc.id
  subnets                = data.aws_subnets.private.ids
  create_db_subnet_group = true
  security_group_rules = {
    private_subnets_ingress = {
      description = "Allow ingress from VPC private subnets"
      cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]
    }
  }

  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 60

  serverlessv2_scaling_configuration = {
    min_capacity = 2
    max_capacity = 2
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
  }

  manage_master_user_password = true
  master_username             = "postgres"
  port                        = 5432

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-public-*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
