provider "aws" {
  region = local.region
}

locals {
  name   = "gh-action-demo"
  region = "us-west-2"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# GitHub OIDC Provider
################################################################################

module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.11"

  # This is one per account
  # Only enable if you do not have a GitHub OIDC provider
  create = false

  tags = local.tags
}

################################################################################
# GitHub OIDC IAM Role
################################################################################

data "aws_iam_policy_document" "iam_github_oidc_role" {
  statement {
    sid = "ReadWriteImage"
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr.repository_arn]
  }

  statement {
    sid       = "ECRLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "StoreTaskDef"
    actions = [
      "s3:GetObject",
      "s3:PubObject",
    ]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }

  statement {
    sid       = "RegisterTaskDef"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid = "UpdateService"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "iam_github_oidc_role" {
  name_prefix = "${local.name}-cicd-"
  description = "GitHub OIDC role permissions"

  policy = data.aws_iam_policy_document.iam_github_oidc_role.json
}

module "iam_github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.11"

  name = "${local.name}-cicd"

  # This should be updated to suit your organization, repository, references/branches, etc.
  subjects = ["repo:${var.repository_owner}/${var.repository_name}:*"]
  policies = {
    custom = aws_iam_policy.iam_github_oidc_role.arn
  }

  tags = local.tags
}

################################################################################
# ECR Repository
################################################################################

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6"

  repository_name                   = local.name
  repository_read_write_access_arns = [one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)]
  repository_read_access_arns       = [module.iam_github_oidc_role.arn]
  repository_force_delete           = true
  create_lifecycle_policy           = false

  tags = local.tags
}

resource "aws_ssm_parameter" "ecr_url" {
  name  = "/ecr/${local.name}/url"
  type  = "String"
  value = module.ecr.repository_url
  tags  = local.tags
}

################################################################################
# S3 Bucket
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix = "task-definition-"
  # acl           = "private"

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

################################################################################
# Supporting Resources
################################################################################

data "aws_iam_roles" "ecs_core_infra_exec_role" {
  name_regex = "core-infra-*"
}
