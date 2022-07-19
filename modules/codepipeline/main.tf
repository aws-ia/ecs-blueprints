resource "aws_codepipeline" "this" {
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
      name             = "Build_app"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]

      configuration = {
        ProjectName = var.codebuild_project_app
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy_app"
      category        = "Deploy"
      owner           = "AWS"
      provider        = var.deploy_provider
      input_artifacts = ["BuildArtifact_app"]
      version         = "1"

      configuration = var.app_deploy_configuration
    }
  }

  lifecycle {
    # prevents github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = var.tags
}

resource "aws_codestarnotifications_notification_rule" "this" {
  name        = "${var.name}_pipeline_execution_status"
  detail_type = "FULL"

  event_type_ids = [
    "codepipeline-pipeline-action-execution-succeeded",
    "codepipeline-pipeline-action-execution-failed"
  ]
  resource = aws_codepipeline.this.arn

  target {
    address = var.sns_topic
  }

  tags = var.tags
}
