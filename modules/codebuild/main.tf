data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_codebuild_project" "aws_codebuild" {
  name          = var.name
  description   = "Terraform CodeBuild project"
  build_timeout = "10"
  service_role  = var.iam_role

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "REPO_URL"
      value = var.ecr_repo_url
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "DYNAMODB_TABLE"
      value = var.dynamodb_table_name
    }

    environment_variable {
      name  = "TASK_DEFINITION_FAMILY"
      value = var.task_definition_family
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.container_name
    }

    environment_variable {
      name  = "SERVICE_PORT"
      value = var.service_port
    }

    environment_variable {
      name  = "FOLDER_PATH"
      value = var.folder_path
    }

    environment_variable {
      name  = "ECS_ROLE"
      value = var.ecs_role
    }

    environment_variable {
      name  = "ECS_TASK_ROLE"
      value = var.ecs_task_role
    }

    environment_variable {
      name  = "SERVER_ALB_URL"
      value = var.server_alb_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.container_name}"
      stream_name = "/codebuild/${var.container_name}/build/"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  tags = var.tags
}
