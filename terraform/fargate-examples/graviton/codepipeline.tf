module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6"

  repository_name = local.container_name

  repository_force_delete = true
  create_lifecycle_policy = false
  repository_read_access_arns = [
    module.ecs_service_amd64.task_exec_iam_role_arn,
    module.ecs_service_arm64.task_exec_iam_role_arn
  ]
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

module "codebuild_ci_amd64" {
  source = "../../modules/codebuild"

  name           = "codebuild-amd64-${module.ecs_service_amd64.name}"
  service_role   = module.codebuild_ci_amd64.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_amd64.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = module.ecs_service_amd64.task_exec_iam_role_arn
        }, {
        name  = "IMG_SUFFIX_ARCH"
        value = "amd64"
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-amd64-${random_id.this.hex}"
  ecr_repository  = module.ecr.repository_arn

  tags = local.tags
}

module "codebuild_ci_arm64" {
  source = "../../modules/codebuild"

  name           = "codebuild-arm-${module.ecs_service_arm64.name}"
  service_role   = module.codebuild_ci_arm64.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    compute_type    = "BUILD_GENERAL1_LARGE"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
    type            = "ARM_CONTAINER"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_arm64.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = module.ecs_service_arm64.task_exec_iam_role_arn
        }, {
        name  = "IMG_SUFFIX_ARCH"
        value = "arm64v8"
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-arm-${random_id.this.hex}"
  ecr_repository  = module.ecr.repository_arn

  tags = local.tags
}

module "codebuild_ci_manifest" {
  source = "../../modules/codebuild"

  name           = "codebuild-manifest-${local.name}"
  service_role   = module.codebuild_ci_manifest.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec_manifest.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.ecr.repository_url
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = module.ecs_service_amd64.task_exec_iam_role_arn
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-manifest-${random_id.this.hex}"
  ecr_repository  = module.ecr.repository_arn

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
    name = "Build_image"
    action = [{
      name            = "Build_app_amd64"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = module.codebuild_ci_amd64.project_id
      }
      }, {
      name            = "Build_app_arm64"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = module.codebuild_ci_arm64.project_id
      }
    }],
    }, {
    name = "Build_manifest"
    action = [{
      name             = "Build_manifest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]
      configuration = {
        ProjectName = module.codebuild_ci_manifest.project_id
      }
    }],
    }, {
    name = "Deploy"
    action = [{
      name            = "Deploy_amd64"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_amd64.name
        FileName    = "imagedefinition.json"
      }
      }, {
      name            = "Deploy_arm64"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_arm64.name
        FileName    = "imagedefinition.json"
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${local.name}-pipeline-${random_id.this.hex}"

  tags = local.tags
}
