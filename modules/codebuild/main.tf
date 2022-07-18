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
          type  = environment_variable.value.type
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
