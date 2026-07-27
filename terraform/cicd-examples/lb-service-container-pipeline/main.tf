provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  target_cluster_name        = "core-infra-external-state"
  target_service_name        = "ecsdemo-frontend"
  codedeploy_application     = "deploy_development_ecsdemo-frontend"
  codedeploy_deployment      = "deployment-group-deploy_development_ecsdemo-frontend"
  target_service_arn         = "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${local.target_cluster_name}/${local.target_service_name}"
  target_task_definition     = "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.target_service_name}:*"
  codedeploy_application_arn = "arn:${data.aws_partition.current.partition}:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:application:${local.codedeploy_application}"
  codedeploy_group_arn       = "arn:${data.aws_partition.current.partition}:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:${local.codedeploy_application}/${local.codedeploy_deployment}"
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/dev-lb-service-codebuild"
  retention_in_days = 7
}

################################################################################
# ECR and Git Repositories
################################################################################

# CodeCommit repository
resource "aws_codecommit_repository" "example_repo" {
  repository_name = "ecs_service_repo"
}

resource "aws_ecr_repository" "example_repo" {
  name                 = "ecs_service_repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

################################################################################
# CodePipleine IAM role
################################################################################

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "codepipeline-app"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSourceRepository"
        Effect = "Allow"
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
        ]
        Resource = aws_codecommit_repository.example_repo.arn
      },
      {
        Sid    = "ReadArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
        ]
        Resource = module.codepipeline_s3_bucket.s3_bucket_arn
      },
      {
        Sid    = "ReadWriteArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = "${module.codepipeline_s3_bucket.s3_bucket_arn}/*"
      },
      {
        Sid    = "RunContainerBuild"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ]
        Resource = module.build_container.project_arn
      },
      {
        Sid    = "DeployApplication"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = [
          local.codedeploy_application_arn,
          local.codedeploy_group_arn,
        ]
      },
      {
        Sid      = "ReadDeploymentState"
        Effect   = "Allow"
        Action   = ["codedeploy:GetDeployment"]
        Resource = "arn:${data.aws_partition.current.partition}:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deployment:*"
      },
      {
        Sid      = "ReadDeploymentConfiguration"
        Effect   = "Allow"
        Action   = ["codedeploy:GetDeploymentConfig"]
        Resource = "arn:${data.aws_partition.current.partition}:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"
      },
      {
        Sid    = "RegisterDeploymentTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "PassDeploymentTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          var.target_task_execution_role_arn,
          var.target_task_role_arn,
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
    ]
  })
}

################################################################################
# CodeBuild Container Build Permissions
################################################################################

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-to-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-container"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
        ]
        Resource = module.codepipeline_s3_bucket.s3_bucket_arn
      },
      {
        Sid    = "ReadWriteArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = "${module.codepipeline_s3_bucket.s3_bucket_arn}/*"
      },
      {
        Sid      = "AuthorizeECR"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushContainerImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.example_repo.arn
      },
      {
        Sid      = "ReadTargetService"
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices"]
        Resource = local.target_service_arn
      },
      {
        Sid      = "ReadTargetTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition"]
        Resource = local.target_task_definition
      },
      {
        Sid    = "WriteBuildLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.codebuild.arn}:*"
      },
    ]
  })
}

################################################################################
# CodeBuild Module
################################################################################

resource "random_id" "this" {
  byte_length = 8
}

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.15"

  bucket_prefix = "codepipeline-${var.region}-"
  # acl           = "private"

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
}

module "build_container" {
  source = "../../modules/codebuild"

  name           = "dev-lb-service-codebuild"
  service_role   = aws_iam_role.codebuild_role.arn
  buildspec_path = "./buildspec-cicd.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    image           = "aws/codebuild/standard:5.0"
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = aws_ecr_repository.example_repo.repository_url
      }
    ]
  }

  logs_config = {
    cloudwatch_logs = {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  create_iam_role = false
  iam_role_name   = "dev-codebuild-${random_id.this.hex}"
  ecr_repository  = aws_ecr_repository.example_repo.arn

  depends_on = [aws_iam_role_policy.codebuild]
}

################################################################################
# CodePipeline
################################################################################

resource "aws_codepipeline" "example_application_pipeline" {
  name     = "example-application-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  depends_on = [aws_iam_role_policy.codepipeline]

  artifact_store {
    location = module.codepipeline_s3_bucket.s3_bucket_id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName = aws_codecommit_repository.example_repo.repository_name
        BranchName     = "main" # Replace with your branch name
      }
    }
  }

  stage {
    name = "build-lb-service"

    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = module.build_container.project_id
      }
    }
  }

  stage {
    name = "deploy-lb-service"

    action {
      name            = "deploy-action"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName                = local.codedeploy_application
        DeploymentGroupName            = local.codedeploy_deployment
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "development-task-definition.json"
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "development-appspec.json"
      }
    }
  }

  # You can add more stages for deployment or testing as needed
}
