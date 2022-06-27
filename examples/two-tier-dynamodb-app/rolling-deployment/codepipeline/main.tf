resource "aws_codepipeline" "aws_codepipeline" {
  name     = var.name
  role_arn = var.pipe_role

  artifact_store {
    location = var.s3_bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        OAuthToken           = var.github_token
        Owner                = var.repo_owner
        Repo                 = var.repo_name
        Branch               = var.branch
        PollForSourceChanges = true
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build_server"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_server"]

      configuration = {
        ProjectName = var.codebuild_project_server
      }
    }

    action {
      name             = "Build_client"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_client"]
      configuration = {
        ProjectName = var.codebuild_project_client
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy_server"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["BuildArtifact_server"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name_server
        FileName    = "imagedefinition.json"
      }
    }

    action {
      name            = "Deploy_client"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["BuildArtifact_client"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name_client
        FileName    = "imagedefinition.json"
      }
    }
  }

  lifecycle {
    # prevents github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration]
  }

}

resource "aws_codestarnotifications_notification_rule" "codepipeline" {
  name        = "pipeline_execution_status"
  detail_type = "FULL"

  event_type_ids = [
    "codepipeline-pipeline-action-execution-succeeded",
    "codepipeline-pipeline-action-execution-failed"
  ]
  resource = aws_codepipeline.aws_codepipeline.arn

  target {
    address = var.sns_topic
  }
}
