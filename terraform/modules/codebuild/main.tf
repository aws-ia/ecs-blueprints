data "aws_partition" "current" {}

data "aws_s3_bucket" "example" {
  bucket = var.s3_bucket
}

resource "aws_codebuild_project" "this" {
  name          = var.name
  description   = var.description
  build_timeout = var.build_timeout
  service_role  = var.service_role

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = var.compute_type
    image        = var.build_image
    type         = var.image_type

    environment_variable {
      name  = "REPO_URL"
      value = var.ecr_repository_url
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = file(var.buildspec_path)
  }
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
    resources = ["${data.aws_s3_bucket.example.arn}/*"]
    #resources = ["*"]
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
