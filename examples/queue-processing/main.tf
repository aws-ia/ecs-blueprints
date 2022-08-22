provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name = var.service_name

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/terraform-aws-ecs-blueprints"
  }

  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value == "" ? "${var.core_stack_name}-private-" : var.private_subnets_tag_value

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

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
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
      from_port   = var.container_port
      to_port     = var.container_port
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}

module "container_image_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = var.container_name

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [data.aws_iam_role.ecs_core_infra_exec_role.arn]
  repository_read_write_access_arns = [module.codepipeline_ci_cd.codepipeline_role_arn]

  tags = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.container_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = data.aws_iam_role.ecs_core_infra_exec_role.arn
  container_definitions    = jsonencode([
    {
      name      = var.container_name
      image     = "${module.container_image_ecr.repository_url}:654ff8e"
    logConfiguration = {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": var.aws_region,
        "awslogs-group": aws_cloudwatch_log_group.this.name,
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
  ])
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_in_days

  tags = local.tags
}

################################################################################
# Lambda Function ECS scaling trigger
################################################################################

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${local.name}-${random_id.this.hex}"
  description   = "Automatically invoke ECS tasks based on SQS queue size and available tasks"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  publish       = true

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.lambda_role.json
  # create_package         = false
  source_path = "./application-code/lambda-function-trigger/"

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {

  }

  allowed_triggers = {
    PollSSMScale = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.fargate_scaling.arn
    }
  }

  tags = local.tags
}

################################################################################
# Cloudwatch Events (EventBridge)
################################################################################

resource "aws_cloudwatch_event_rule" "fargate_scaling" {
  name                = "ECSTaskTriggerScheduler"
  description         = "This rule is used for autoscaling ECS with Lambda"
  schedule_expression = "rate(2 minutes)"

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "ecs_fargate_lambda_function" {
  rule = aws_cloudwatch_event_rule.fargate_scaling.name
  arn  = module.lambda_function.lambda_function_arn
}

################################################################################
# S3 Buckets and SQS Queue
################################################################################

module "source_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name}-source-${var.aws_region}-${random_id.this.hex}"
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

module "destination_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name}-destination-${var.aws_region}-${random_id.this.hex}"
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

module "processing_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 2.0"

  name = "${local.name}-processing-queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SQSSendMessageS3"
        Effect   = "Allow"
        Action   = "SQS:SendMessage"
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.name}-processing-queue"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.source_s3_bucket.s3_bucket_id

  queue {
    queue_arn     = module.processing_queue.this_sqs_queue_arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:Post", "s3:ObjectCreated:Copy"]
    filter_prefix = "ecsproc/"
    filter_suffix = ".jpg"
  }
}

################################################################################
# ECS Scaling Params
################################################################################

resource "aws_ssm_parameter" "ecs_pipeline_enabled" {
  name  = "PIPELINE_ENABLED"
  type  = "String"
  value = 1
}

resource "aws_ssm_parameter" "ecs_pipeline_max_tasks" {
  name  = "PIPELINE_ECS_MAX_TASKS"
  type  = "String"
  value = 10
}

resource "aws_ssm_parameter" "sqs_processing_queue" {
  name  = "PIPELINE_UNPROCESSED_SQS_URL"
  type  = "String"
  value = module.processing_queue.this_sqs_queue_name
}

resource "aws_ssm_parameter" "s3_destination_bucket" {
  name  = "PIPELINE_S3_DEST_BUCKET"
  type  = "String"
  value = module.destination_s3_bucket.s3_bucket_arn
}

resource "aws_ssm_parameter" "s3_destination_prefix" {
  name  = "PIPELINE_S3_DEST_PREFIX"
  type  = "String"
  value = "processed"
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name  = "PIPELINE_ECS_CLUSTER"
  type  = "String"
  value = data.aws_ecs_cluster.core_infra.cluster_name
}

resource "aws_ssm_parameter" "ecs_task_definition" {
  name  = "PIPELINE_ECS_TASK_DEFINITON"
  type  = "String"
  value = aws_ecs_task_definition.this.arn
}

resource "aws_ssm_parameter" "ecs_task_container_name" {
  name  = "PIPELINE_ECS_TASK_CONTAINER"
  type  = "String"
  value = var.container_name
}

resource "aws_ssm_parameter" "ecs_task_subnet" {
  name  = "PIPELINE_ECS_TASK_SUBNET"
  type  = "String"
  value = data.aws_subnets.private.ids[0]
}

resource "aws_ssm_parameter" "ecs_task_security_group" {
  name  = "PIPELINE_ECS_TASK_SECURITYGROUP"
  type  = "String"
  value = module.service_task_security_group.security_group_id
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

module "codebuild_ci" {
  source = "../../modules/codebuild"

  name           = "codebuild-${local.name}"
  service_role   = module.codebuild_ci.codebuild_role_arn
  buildspec_path = var.buildspec_path
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.container_image_ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = aws_ecs_task_definition.this.family
        }, {
        name  = "CONTAINER_NAME"
        value = var.container_name
        }, {
        name  = "SERVICE_PORT"
        value = var.container_port
        }, {
        name  = "FOLDER_PATH"
        value = var.folder_path
        }, {
        name  = "QUEUE_NAME"
        value = module.processing_queue.this_sqs_queue_name
        }, {
        name  = "DESTINATION_BUCKET"
        value = module.destination_s3_bucket.s3_bucket_id
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = data.aws_iam_role.ecs_core_infra_exec_role.arn
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-codebuild-${random_id.this.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

module "codepipeline_ci_cd" {
  source = "../../modules/codepipeline"

  name         = "pipeline-${local.name}"
  service_role = module.codepipeline_ci_cd.codepipeline_role_arn
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
        ProjectName = module.codebuild_ci.project_id
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${local.name}-pipeline-${random_id.this.hex}"

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}

################################################################################
# Task Role
################################################################################

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task.json

  tags = local.tags
}

data "aws_iam_policy_document" "task" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${local.name}-task"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_role.json
}

data "aws_iam_policy_document" "task_role" {

  statement {
    sid       = "IAMPassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    sid = "SQSReadWrite"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:SendMessage",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]
    resources = [module.processing_queue.this_sqs_queue_arn]
  }

  statement {
    sid = "S3Read"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"

    ]
    resources = [
      module.source_s3_bucket.s3_bucket_arn,
      "${module.source_s3_bucket.s3_bucket_arn}/*",
      module.destination_s3_bucket.s3_bucket_arn,
      "${module.destination_s3_bucket.s3_bucket_arn}/*"
    ]
  }

  statement {
    sid = "SSMRead"
    actions = [
      "ssm:GetParameters",
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_role" {

  statement {
    sid       = "IAMPassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    sid = "SQSReadWrite"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:SendMessage",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]
    resources = [module.processing_queue.this_sqs_queue_arn]

  }
  statement {
    sid = "ECSTaskReadWrite"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:StartTask",
      "ecs:RunTask"
    ]
    resources = ["*"]
  }

  statement {
    sid = "SSMRead"
    actions = [
      "ssm:GetParameters",
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/*",
    ]
  }
}
