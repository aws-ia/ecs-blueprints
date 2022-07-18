provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  app_server_port = 3001
  app_client_port = 80

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/terraform-aws-ecs-blueprints"
  }
}

################################################################################
# Data Sources from core-infra
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = [var.vpc_tag_value]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${var.private_subnets}*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${var.public_subnets}*"]
  }
}

data "aws_subnet" "public_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name
}

################################################################################
# ECS Blueprint
################################################################################

module "client_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-client"
  description = "Security group for client application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]

  tags = local.tags
}

module "client_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name = "${local.name}-client"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.client_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "client"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = local.app_client_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

module "server_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-client"
  description = "Security group for client application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.client_alb_security_group.security_group_id
    },
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = [for s in data.aws_subnet.public_cidr : s.cidr_block]

  tags = local.tags
}

module "server_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name = "${local.name}-server"

  load_balancer_type = "application"
  internal           = true

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.server_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "server"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      health_check = {
        path    = "/status"
        port    = local.app_server_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

module "server_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = "${local.name}-server"

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [data.aws_iam_role.ecs_core_infra_exec_role.arn]
  repository_read_write_access_arns = [module.devops_role.devops_role_arn]

  tags = local.tags
}

module "client_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = "${local.name}-client"

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [data.aws_iam_role.ecs_core_infra_exec_role.arn]
  repository_read_write_access_arns = [module.devops_role.devops_role_arn]

  tags = local.tags
}

data "aws_iam_policy_document" "task_role" {
  statement {
    sid = "S3Read"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      module.assets_s3_bucket.s3_bucket_arn,
      "${module.assets_s3_bucket.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid       = "IAMPassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    sid = "DynamoDBReadWrite"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [module.assets_dynamodb_table.dynamodb_table_arn]
  }
}

module "client_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-client-task"
  description = "Security group for client task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.client_alb_security_group.security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

module "server_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-server-task"
  description = "Security group for server task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      from_port                = local.app_server_port
      to_port                  = local.app_server_port
      protocol                 = "tcp"
      source_security_group_id = module.server_alb_security_group.security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

module "ecs_service_server" {
  source = "../../modules/ecs-service"

  name           = "${local.name}-server"
  desired_count  = 1
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.arn

  security_groups = [module.server_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  load_balancers = [{
    target_group_arn = element(module.server_alb.target_group_arns, 0)
  }]
  deployment_controller = "ECS"

  # Task Definition
  container_name     = "${local.name}-server"
  container_port     = local.app_server_port
  cpu                = 256
  memory             = 512
  image              = module.server_ecr.repository_url
  task_role_policy   = data.aws_iam_policy_document.task_role.json
  execution_role_arn = data.aws_iam_role.ecs_core_infra_exec_role.arn

  tags = local.tags
}

module "ecs_service_client" {
  source = "../../modules/ecs-service"

  name           = "${local.name}-client"
  desired_count  = 1
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.arn

  security_groups = [module.client_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  load_balancers = [{
    target_group_arn = element(module.client_alb.target_group_arns, 0)
  }]
  deployment_controller = "ECS"

  # Task Definition
  container_name     = "${local.name}-client"
  container_port     = local.app_client_port
  cpu                = 256
  memory             = 512
  image              = module.client_ecr.repository_url
  task_role_policy   = data.aws_iam_policy_document.task_role.json
  execution_role_arn = data.aws_iam_role.ecs_core_infra_exec_role.arn

  tags = local.tags
}

module "ecs_autoscaling_server" {
  source = "../../modules/ecs-autoscaling"

  cluster_name     = data.aws_ecs_cluster.core_infra.cluster_name
  service_name     = module.ecs_service_server.name
  min_capacity     = 1
  max_capacity     = 5
  cpu_threshold    = 75
  memory_threshold = 75
}

module "ecs_autoscaling_client" {
  source = "../../modules/ecs-autoscaling"

  cluster_name     = data.aws_ecs_cluster.core_infra.cluster_name
  service_name     = module.ecs_service_client.name
  min_capacity     = 1
  max_capacity     = 5
  cpu_threshold    = 75
  memory_threshold = 74
}

################################################################################
# CodePipeline
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "codepipeline-${local.region}-${random_id.this.hex}"
  acl    = "private"

  # For example only - please re-evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_sns_topic" "codestar_notification" {
  name = local.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteAccess"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${local.region}:${data.aws_caller_identity.current.account_id}:${local.name}"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

module "devops_role" {
  source = "../../modules/iam"

  create_devops_role = true

  name                = "${local.name}-devops"
  ecr_repositories    = [module.server_ecr.repository_arn, module.client_ecr.repository_arn]
  code_build_projects = [module.codebuild_client.project_arn, module.codebuild_server.project_arn]

  tags = local.tags
}

module "codebuild_server" {
  source = "../../modules/codebuild"

  name           = "codebuild-${local.name}-server"
  service_role   = module.devops_role.devops_role_arn
  buildspec_path = var.buildspec_path

  environment = {
    environment_variables = {
      REPO_URL               = module.server_ecr.repository_url
      DYNAMODB_TABLE         = module.assets_dynamodb_table.dynamodb_table_id
      TASK_DEFINITION_FAMILY = module.ecs_service_server.task_definition_family
      CONTAINER_NAME         = module.ecs_service_server.container_name
      SERVICE_PORT           = local.app_server_port
      FOLDER_PATH            = var.folder_path_server
      ECS_TASK_ROLE_ARN      = module.ecs_service_server.task_role_arn
      ECS_EXEC_ROLE_ARN      = data.aws_iam_role.ecs_core_infra_exec_role.arn
    }
  }

  tags = local.tags
}

module "codebuild_client" {
  source = "../../modules/codebuild"

  name           = "codebuild-${local.name}-client"
  service_role   = module.devops_role.devops_role_arn
  buildspec_path = var.buildspec_path

  environment = {
    environment_variables = {
      REPO_URL               = module.client_ecr.repository_url
      TASK_DEFINITION_FAMILY = module.ecs_service_client.task_definition_family
      CONTAINER_NAME         = module.ecs_service_client.container_name
      SERVICE_PORT           = local.app_client_port
      FOLDER_PATH            = var.folder_path_client
      ECS_TASK_ROLE_ARN      = module.ecs_service_client.task_role_arn
      ECS_EXEC_ROLE_ARN      = data.aws_iam_role.ecs_core_infra_exec_role.arn
      SERVER_ALB_URL         = module.server_alb.lb_dns_name
    }
  }

  tags = local.tags
}

data "aws_secretsmanager_secret" "github_token" {
  name = "ecs-github-token"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

module "codepipeline" {
  source = "../../modules/codepipeline"

  name                     = "pipeline-${local.name}"
  pipe_role                = module.devops_role.devops_role_arn
  s3_bucket                = module.codepipeline_s3_bucket.s3_bucket_id
  github_token             = data.aws_secretsmanager_secret_version.github_token.secret_string
  repo_owner               = var.repository_owner
  repo_name                = var.repository_name
  branch                   = var.repository_branch
  codebuild_project_server = module.codebuild_server.project_id
  codebuild_project_client = module.codebuild_client.project_id
  sns_topic                = aws_sns_topic.codestar_notification.arn

  client_deploy_configuration = {
    ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
    ServiceName = module.ecs_service_client.name
    FileName    = "imagedefinition.json"
  }
  server_deploy_configuration = {
    ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
    ServiceName = module.ecs_service_server.name
    FileName    = "imagedefinition.json"
  }

  tags = local.tags
}

################################################################################
# Assets
################################################################################

module "assets_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name}-assets-${local.region}-${random_id.this.hex}"
  acl    = "private"

  # For example only - please evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

module "assets_dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 2.0"

  name     = "${local.name}-assets"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "N"
    }
  ]

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}
