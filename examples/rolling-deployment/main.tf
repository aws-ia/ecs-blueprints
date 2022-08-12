provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  name = basename(path.cwd)

  app_server_port = 3001
  app_client_port = 80

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/terraform-aws-ecs-blueprints"
  }

  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.vpc_tag_value == "" ? "${var.core_stack_name}-private-" : var.vpc_tag_value
  tag_val_public_subnet  = var.vpc_tag_value == "" ? "${var.core_stack_name}-public-" : var.vpc_tag_value

}

################################################################################
# Data Sources from ecs-blueprint-infra
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = [local.tag_val_vpc]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_private_subnet}*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_public_subnet}*"]
  }
}

data "aws_subnet" "public_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
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

  name        = "${local.name}-server"
  description = "Security group for server application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.client_task_security_group.security_group_id
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
  repository_read_write_access_arns = [module.codepipeline_server.codepipeline_role_arn]

  tags = local.tags
}

module "client_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = "${local.name}-client"

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [data.aws_iam_role.ecs_core_infra_exec_role.arn]
  repository_read_write_access_arns = [module.codepipeline_client.codepipeline_role_arn]

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
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name

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

  # Autoscalnig
  enable_autoscaling           = true
  autoscaling_min_capacity     = 1
  autoscaling_max_capacity     = 5
  autoscaling_cpu_threshold    = 75
  autoscaling_memory_threshold = 75

  tags = local.tags
}

module "ecs_service_client" {
  source = "../../modules/ecs-service"

  name           = "${local.name}-client"
  desired_count  = 1
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name

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

  # Autoscaling
  enable_autoscaling           = true
  autoscaling_min_capacity     = 1
  autoscaling_max_capacity     = 5
  autoscaling_cpu_threshold    = 75
  autoscaling_memory_threshold = 75

  tags = local.tags
}

################################################################################
# CodePipeline
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "codepipeline-${var.aws_region}-${random_id.this.hex}"
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
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.name}"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

module "codebuild_server" {
  source = "../../modules/codebuild"

  name           = "codebuild-${module.ecs_service_server.name}"
  service_role   = module.codebuild_server.codebuild_role_arn
  buildspec_path = var.buildspec_path
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.server_ecr.repository_url
        }, {
        name  = "DYNAMODB_TABLE"
        value = module.assets_dynamodb_table.dynamodb_table_id
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_server.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = module.ecs_service_server.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.app_server_port
        }, {
        name  = "FOLDER_PATH"
        value = var.folder_path_server
        }, {
        name  = "ECS_TASK_ROLE_ARN"
        value = module.ecs_service_server.task_role_arn
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = data.aws_iam_role.ecs_core_infra_exec_role.arn
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${module.ecs_service_server.name}-codebuild-${random_id.server.hex}"
  ecr_repository  = module.server_ecr.repository_arn

  tags = local.tags
}

module "codebuild_client" {
  source = "../../modules/codebuild"

  name           = "codebuild-${module.ecs_service_client.name}"
  service_role   = module.codebuild_client.codebuild_role_arn
  buildspec_path = var.buildspec_path
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.client_ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_client.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = module.ecs_service_client.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.app_client_port
        }, {
        name  = "FOLDER_PATH"
        value = var.folder_path_client
        }, {
        name  = "ECS_TASK_ROLE_ARN"
        value = module.ecs_service_client.task_role_arn
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = data.aws_iam_role.ecs_core_infra_exec_role.arn
        }, {
        name  = "SERVER_ALB_URL"
        value = module.server_alb.lb_dns_name
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${module.ecs_service_client.name}-codebuild-${random_id.client.hex}"
  ecr_repository  = module.client_ecr.repository_arn

  tags = local.tags
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

module "codepipeline_server" {
  source = "../../modules/codepipeline"

  name         = "pipeline-${module.ecs_service_server.name}"
  service_role = module.codepipeline_server.codepipeline_role_arn
  s3_bucket    = module.codepipeline_s3_bucket
  sns_topic    = aws_sns_topic.codestar_notification.arn

  stage = [{
    name = "Source"
    action = [{
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["SourceArtifact"]
      configuration = {
        OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
        Owner                = var.repository_owner
        Repo                 = var.repository_name
        Branch               = var.repository_branch
        PollForSourceChanges = true
      }
    }],
    }, {
    name = "Build"
    action = [{
      name             = "Build_app"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]
      configuration = {
        ProjectName = module.codebuild_server.project_id
      }
    }],
    }, {
    name = "Deploy"
    action = [{
      name            = "Deploy_app"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_server.name
        FileName    = "imagedefinition.json"
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${module.ecs_service_server.name}-pipeline-${random_id.server.hex}"

  tags = local.tags
}

module "codepipeline_client" {
  source = "../../modules/codepipeline"

  name         = "pipeline-${module.ecs_service_client.name}"
  service_role = module.codepipeline_client.codepipeline_role_arn
  s3_bucket    = module.codepipeline_s3_bucket
  sns_topic    = aws_sns_topic.codestar_notification.arn

  stage = [{
    name = "Source"
    action = [{
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["SourceArtifact"]
      configuration = {
        OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
        Owner                = var.repository_owner
        Repo                 = var.repository_name
        Branch               = var.repository_branch
        PollForSourceChanges = true
      }
    }],
    }, {
    name = "Build"
    action = [{
      name             = "Build_app"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]
      configuration = {
        ProjectName = module.codebuild_client.project_id
      }
    }],
    }, {
    name = "Deploy"
    action = [{
      name            = "Deploy_app"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_client.name
        FileName    = "imagedefinition.json"
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${module.ecs_service_client.name}-pipeline-${random_id.client.hex}"

  tags = local.tags
}

################################################################################
# Assets
################################################################################

module "assets_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name}-assets-${var.aws_region}-${random_id.this.hex}"
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

resource "random_id" "client" {
  byte_length = "2"
}

resource "random_id" "server" {
  byte_length = "2"
}
