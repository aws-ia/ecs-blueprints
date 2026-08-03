provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name     = var.name
  region   = var.aws_region
  vpc_cidr = "10.30.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  container_name = var.name

  scaling_policy_name       = "ecs_sqs_scaling"
  desired_latency           = 60
  default_msg_proc_duration = 5
  number_of_messages        = 50
  app_metric_name           = "MsgProcessingDuration"
  bpi_metric_name           = "ecsTargetBPI"
  metric_type               = "Single-Queue"
  metric_namespace          = "ECS-SQS-BPI"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# Self-contained infrastructure
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  # Queue workers receive no inbound traffic; the NAT gateway provides the
  # outbound path to ECR, SQS, and CloudWatch. Single NAT keeps cost down for
  # a demo - use one per AZ for production availability.
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = local.name

  # Container Insights supplies the ECS/ContainerInsights RunningTaskCount
  # metric that the backlog-per-task scaling expression divides by.
  setting = [{
    name  = "containerInsights"
    value = "enhanced"
  }]

  tags = local.tags
}

################################################################################
# ECS Blueprint
################################################################################

module "container_image_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6"

  repository_name = local.container_name

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [aws_iam_role.execution.arn]
  repository_read_write_access_arns = [module.codepipeline_ci_cd.codepipeline_role_arn]

  tags = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.container_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn
  container_definitions = jsonencode([
    {
      name  = local.container_name
      image = module.container_image_ecr.repository_url
      environment = [
        {
          # Set explicitly so the app never falls back to a hardcoded or
          # guessed region (see application-code/ecsdemo-queue-proc/src/app.py)
          name  = "AWS_REGION",
          value = local.region
        },
        {
          name  = "queue_name",
          value = module.processing_queue.queue_name
        },
        {
          name  = "app_metric_name",
          value = local.app_metric_name
        },
        {
          name  = "metric_type",
          value = local.metric_type
        },
        {
          name  = "metric_namespace",
          value = local.metric_namespace
        },

      ]
      logConfiguration = {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-region" : local.region,
          "awslogs-group" : aws_cloudwatch_log_group.this.name,
          "awslogs-stream-prefix" : "ecs"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }

  tags = local.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = local.name
  desired_count                       = 1
  cluster_arn                         = module.ecs_cluster.arn
  enable_autoscaling                  = false

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  create_iam_role        = false
  create_task_definition = false
  task_definition_arn    = aws_ecs_task_definition.this.arn

  enable_execute_command = true

  tags = local.tags
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${module.ecs_cluster.name}/${module.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_sqs_app_scaling_policy" {
  name               = local.scaling_policy_name
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 12
    scale_out_cooldown = 240
    scale_in_cooldown  = 240

    customized_metric_specification {

      metrics {
        label = "Get the queue size (the number of messages waiting to be processed)"
        id    = "m1"

        metric_stat {
          metric {
            metric_name = "ApproximateNumberOfMessagesVisible"
            namespace   = "AWS/SQS"

            dimensions {
              name  = "QueueName"
              value = module.processing_queue.queue_name
            }
          }

          stat = "Average"
        }

        return_data = false
      }

      metrics {
        label = "Get the ECS running task count (the number of currently running tasks)"
        id    = "m2"

        metric_stat {
          metric {
            metric_name = "RunningTaskCount"
            namespace   = "ECS/ContainerInsights"

            dimensions {
              name  = "ClusterName"
              value = module.ecs_cluster.name
            }

            dimensions {
              name  = "ServiceName"
              value = module.ecs_service.name
            }
          }

          stat = "Average"
        }

        return_data = false
      }

      metrics {
        label       = "Calculate the backlog per instance"
        id          = "e1"
        expression  = "m1 / m2"
        return_data = true
      }
    }
  }
}


resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30

  tags = local.tags
}

################################################################################
# Lambda Function ECS scaling trigger
################################################################################

module "lambda_function_message_producer" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.1"

  function_name      = "${local.name}-message-producer"
  description        = "This function can be used to send test messages to the processing queue and trigger ASG scaling events."
  handler            = "lambda_function.lambda_handler"
  runtime            = "python3.12"
  publish            = true
  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.lambda_role.json
  source_path        = "../../../application-code/message-producer/"

  environment_variables = {
    queue_name                = module.processing_queue.queue_name
    default_msg_proc_duration = local.default_msg_proc_duration
    number_of_messages        = local.number_of_messages
  }

  allowed_triggers = {
    PollSSMScale = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.sqs_message_producer.arn
    }
  }

  cloudwatch_logs_retention_in_days = 30

  tags = local.tags
}

module "lambda_function_target_bpi_update" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.1"

  function_name      = "${local.name}-target_bpi_update"
  description        = "This function regularly updates the target BPI of the ECS Service Target Tracking Policy"
  handler            = "lambda_function.lambda_handler"
  runtime            = "python3.12"
  publish            = true
  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.lambda_role.json
  source_path        = "../../../application-code/ecs-target-setter/"

  environment_variables = {
    scaling_policy_name       = local.scaling_policy_name
    queue_name                = module.processing_queue.queue_name
    app_metric_name           = local.app_metric_name
    metric_type               = local.metric_type
    metric_namespace          = local.metric_namespace
    bpi_metric_name           = local.bpi_metric_name
    default_msg_proc_duration = local.default_msg_proc_duration
    desired_latency           = local.desired_latency
    cluster_name              = module.ecs_cluster.name
    service_name              = module.ecs_service.name
  }

  allowed_triggers = {
    PollSSMScale = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.fargate_scaling.arn
    }
  }

  cloudwatch_logs_retention_in_days = 30

  tags = local.tags
}

################################################################################
# Cloudwatch Events (EventBridge)
################################################################################

resource "aws_cloudwatch_event_rule" "fargate_scaling" {
  name                = "${local.name}-target-bpi-update"
  description         = "This rule is used for update ECS Autoscaling Target BPI"
  schedule_expression = "rate(60 minutes)"

  state = "DISABLED"

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "ecs_fargate_lambda_function" {
  rule = aws_cloudwatch_event_rule.fargate_scaling.name
  arn  = module.lambda_function_target_bpi_update.lambda_function_arn
}

resource "aws_cloudwatch_event_rule" "sqs_message_producer" {
  name                = "${local.name}-message-producer"
  description         = "This rule is used for Send Messages to SQS Queue for testing"
  schedule_expression = "rate(1 minute)"

  state = "DISABLED"

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sqs_message_producer_lambda_function" {
  rule = aws_cloudwatch_event_rule.sqs_message_producer.name
  arn  = module.lambda_function_message_producer.lambda_function_arn
}


################################################################################
# SQS Queue
################################################################################


module "processing_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 4.0"

  name                        = "${local.name}-processing-queue-fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  # Dead-letter queue for poison messages. A FIFO queue's DLQ must itself be
  # FIFO; the module inherits fifo_queue for the DLQ it creates. After
  # maxReceiveCount failed receives, SQS redrives the message to the DLQ so
  # malformed messages are preserved for inspection instead of being retried
  # forever (which permanently inflated the backlog metric and pinned the
  # service scaled out).
  create_dlq = true
  redrive_policy = {
    maxReceiveCount = 5
  }
  dlq_content_based_deduplication = true

  tags = local.tags
}

################################################################################
# CodePipeline
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.15"

  bucket = "codepipeline-${local.region}-${random_id.this.hex}"

  # For example only - please re-evaluate for your environment
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

module "codebuild_ci" {
  source = "../../modules/codebuild"

  name           = "codebuild-${local.name}"
  service_role   = module.codebuild_ci.codebuild_role_arn
  buildspec_path = "./application-code/ecsdemo-queue-proc/templates/buildspec.yml"
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
        value = local.container_name
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/ecsdemo-queue-proc/."
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-codebuild-${random_id.this.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
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
        ClusterName = module.ecs_cluster.name
        ServiceName = module.ecs_service.name
        FileName    = "imagedefinitions.json"
      }
    }],
    }

  ]

  create_iam_role = true
  iam_role_name   = "${local.name}-pipeline-${random_id.this.hex}"
  pass_role_arns = [
    aws_iam_role.execution.arn,
    aws_iam_role.task.arn,
  ]

  tags = local.tags
}

################################################################################
# Task, Execution, and Lambda Roles
################################################################################

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.task.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

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
    resources = [module.processing_queue.queue_arn]
  }

  statement {
    sid       = "PublishProcessingMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
}

data "aws_iam_policy_document" "lambda_role" {

  statement {
    sid = "CWMetrics"
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricData"
    ]
    resources = ["*"]
  }
  statement {
    sid = "AppAutoscalingUpdate"
    actions = [
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:DescribeScalingPolicies"
    ]
    resources = ["*"]
  }
  statement {
    sid     = "IAMPassRole"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.execution.arn,
      aws_iam_role.task.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
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
    resources = [module.processing_queue.queue_arn]

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
