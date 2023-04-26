data "aws_partition" "current" {}

resource "aws_codebuild_project" "this" {
  name          = var.name
  description   = var.description
  build_timeout = var.build_timeout
  service_role  = var.service_role

  artifacts {
    type = "CODEPIPELINE"
  }

  dynamic "environment" {
    for_each = [var.environment]

    content {
      compute_type                = try(environment.value.compute_type, "BUILD_GENERAL1_SMALL")
      image                       = try(environment.value.image, "aws/codebuild/standard:4.0")
      image_pull_credentials_type = try(environment.value.image_pull_credentials_type, null)
      type                        = try(environment.value.type, "LINUX_CONTAINER")
      privileged_mode             = try(environment.value.privileged_mode, null)

      dynamic "environment_variable" {
        for_each = try(environment.value.environment_variables, [])

        content {
          name  = environment_variable.value.name
          value = environment_variable.value.value
          type  = try(environment_variable.value.type, null)
        }
      }
    }
  }

  dynamic "logs_config" {
    for_each = length(var.logs_config) > 0 ? [var.logs_config] : []

    content {
      dynamic "cloudwatch_logs" {
        for_each = try([logs_config.value.cloudwatch_logs], [])

        content {
          group_name  = try(cloudwatch_logs.value.group_name, null)
          status      = try(cloudwatch_logs.value.status, null)
          stream_name = try(cloudwatch_logs.value.stream_name, null)
        }
      }

      dynamic "s3_logs" {
        for_each = try([logs_config.value.s3_logs], [])

        content {
          encryption_disabled = try(s3_logs.value.encryption_disabled, null)
          location            = try(s3_logs.value.location, null)
          status              = try(s3_logs.value.status, null)
          bucket_owner_access = try(s3_logs.value.bucket_owner_access, null)
        }
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  tags = var.tags
}

################################################################################
# IAM
################################################################################

data "aws_iam_policy_document" "assume_role_policy" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid     = "CodebuildAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_use_name_prefix ? null : var.iam_role_name
  name_prefix        = var.iam_role_use_name_prefix ? "${var.iam_role_name}-" : null
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json

  tags = var.tags
}

resource "aws_iam_policy" "this" {
  count = var.create_iam_role ? 1 : 0

  name        = var.iam_role_name
  description = "IAM Policy for Role ${var.iam_role_name}"
  policy      = data.aws_iam_policy_document.this[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.create_iam_role ? 1 : 0

  policy_arn = aws_iam_policy.this[0].arn
  role       = aws_iam_role.this[0].name
}

data "aws_iam_policy_document" "this" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid    = "S3ReadWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:List*"
    ]
    resources = ["${var.s3_bucket.s3_bucket_arn}/*"]
  }
  statement {
    sid    = "ECRReadWrite"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [var.ecr_repository]
  }
  statement {
    sid    = "AllowECRAuthorization"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "ECSReadWriteTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCloudWatchActions"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}
