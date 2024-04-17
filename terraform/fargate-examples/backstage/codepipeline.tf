module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6"

  repository_name = local.container_name

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [module.ecs_service.task_exec_iam_role_arn]
  repository_read_write_access_arns = [module.codepipeline_ci_cd.codepipeline_role_arn]

  tags = local.tags
}

################################################################################
# CodePipeline and CodeBuild for CI/CD
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.15"

  bucket_prefix = "codepipeline-${local.region}-"
  acl           = "private"

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

  # S3 Bucket Ownership Controls
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
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
  buildspec_path = "./templates/buildspec.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    image           = "aws/codebuild/standard:5.0"
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.ecr.repository_url
      },
      {
        name  = "CONTAINER_NAME"
        value = local.container_name
      },
      {
        name  = "BASE_URL"
        value = "http://${module.alb.dns_name}"
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${module.ecs_service.name}-codebuild-${random_id.this.hex}"
  ecr_repository  = module.ecr.repository_arn

  tags = local.tags
}

module "codepipeline_ci_cd" {
  source = "../../modules/codepipeline"

  name         = "pipeline-${module.ecs_service.name}"
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
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service.name
        FileName    = "imagedefinition.json"
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${module.ecs_service.name}-pipeline-${random_id.this.hex}"

  tags = local.tags
}
