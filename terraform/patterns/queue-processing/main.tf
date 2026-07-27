provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "ecsdemo-queue-proc"
  region = "us-west-2"

  container_name = "ecsdemo-queue-proc"

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

  name        = local.name
  cluster_arn = data.aws_ecs_cluster.core_infra.arn

  # Use a Standalone Task Definition (w/o Service)
  desired_count = 0

  # Task Definition
  enable_execute_command = true
  tasks_iam_role_policies = {
    TaskQueue = aws_iam_policy.task_queue.arn
  }

  container_definitions = {
    (local.container_name) = {
      image                    = module.ecr.repository_url
      readonly_root_filesystem = false
    }
  }

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
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

################################################################################
# Lambda Function ECS scaling trigger
################################################################################

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.0"

  function_name      = "${local.name}-${random_id.this.hex}"
  description        = "Automatically invoke ECS tasks based on SQS queue size and available tasks"
  handler            = "lambda_function.lambda_handler"
  runtime            = "python3.9"
  publish            = true
  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.lambda_role.json
  source_path        = "../../../application-code/lambda-function-queue-trigger/"

  cloudwatch_logs_retention_in_days = 30

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
  version = "~> 3.15"

  bucket_prefix = "${local.name}-src-${local.region}-"

  # For example only - please evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

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
  version = "~> 3.15"

  bucket_prefix = "${local.name}-dst-${local.region}-"

  # For example only - please evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 4.0"

  name = "${local.name}-processing-queue"

  create_queue_policy = true
  queue_policy_statements = {
    sns = {
      sid     = "S3Publish"
      actions = ["sqs:SendMessage"]

      principals = [
        {
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        }
      ]

      conditions = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [module.source_s3_bucket.s3_bucket_arn]
      }]
    }
  }

  tags = local.tags
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.source_s3_bucket.s3_bucket_id

  queue {
    queue_arn     = module.sqs.queue_arn
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

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_pipeline_max_tasks" {
  name  = "PIPELINE_ECS_MAX_TASKS"
  type  = "String"
  value = 10

  tags = local.tags
}

resource "aws_ssm_parameter" "sqs_processing_queue" {
  name  = "PIPELINE_UNPROCESSED_SQS_URL"
  type  = "String"
  value = module.sqs.queue_name

  tags = local.tags
}

resource "aws_ssm_parameter" "s3_destination_bucket" {
  name  = "PIPELINE_S3_DEST_BUCKET"
  type  = "String"
  value = module.destination_s3_bucket.s3_bucket_arn

  tags = local.tags
}

resource "aws_ssm_parameter" "s3_destination_prefix" {
  name  = "PIPELINE_S3_DEST_PREFIX"
  type  = "String"
  value = "processed"

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name  = "PIPELINE_ECS_CLUSTER"
  type  = "String"
  value = data.aws_ecs_cluster.core_infra.cluster_name

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_task_definition" {
  name  = "PIPELINE_ECS_TASK_DEFINITION"
  type  = "String"
  value = module.ecs_service.task_definition_arn

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_task_container_name" {
  name  = "PIPELINE_ECS_TASK_CONTAINER"
  type  = "String"
  value = local.container_name

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_task_subnet" {
  name  = "PIPELINE_ECS_TASK_SUBNET"
  type  = "String"
  value = data.aws_subnets.private.ids[0]

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_task_security_group" {
  name  = "PIPELINE_ECS_TASK_SECURITYGROUP"
  type  = "String"
  value = module.ecs_service.security_group_id

  tags = local.tags
}

################################################################################
# Task and Lambda Roles
################################################################################

resource "aws_iam_policy" "task_queue" {
  name   = "${local.name}-queue"
  policy = data.aws_iam_policy_document.task_queue.json
}

data "aws_iam_policy_document" "task_queue" {
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
    resources = [module.sqs.queue_arn]
  }

  statement {
    sid = "S3ReadWrite"
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
      "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter",
      "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*",
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
    sid = "SQSReadAttributes"
    actions = [
      "sqs:GetQueueAttributes"
    ]
    resources = [module.sqs.queue_arn]
  }

  statement {
    sid = "ECSTaskReadWrite"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:StartTask",
      "ecs:RunTask",
      "ecs:TagResource"
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
      "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter",
      "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*",
    ]
  }
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

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}
