# IAM role for CodeBuild
resource "aws_iam_role" "this" {
  name = var.iam_role_name

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

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/codebuild/${var.name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_policy" "codebuild_all_permissions" {
  description = "Least-privilege deployment policy for the ${var.name} CodeBuild project"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        {
          Sid    = "WriteBuildLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Resource = "${aws_cloudwatch_log_group.this.arn}:*"
        },
        {
          Sid    = "ReadArtifactAndStateBucket"
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:ListBucket",
          ]
          Resource = var.artifact_bucket_arn
        },
        {
          Sid    = "ReadWriteArtifactsAndState"
          Effect = "Allow"
          Action = [
            "s3:DeleteObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
          ]
          Resource = "${var.artifact_bucket_arn}/*"
        },
        {
          Sid      = "ReadStateBucketParameter"
          Effect   = "Allow"
          Action   = ["ssm:GetParameter", "ssm:GetParameters"]
          Resource = var.terraform_state_parameter_arn
        },
      ],
      flatten([
        for index, service in sort(keys(var.pass_role_arns_by_service)) :
        length(var.pass_role_arns_by_service[service]) == 0 ? [] : [
          {
            Sid      = "PassDeploymentRoles${index}"
            Effect   = "Allow"
            Action   = ["iam:PassRole"]
            Resource = var.pass_role_arns_by_service[service]
            Condition = {
              StringEquals = {
                "iam:PassedToService" = service
              }
            }
          }
        ]
      ]),
      [
        for statement in var.deployment_policy_statements : {
          Sid      = statement.sid
          Effect   = "Allow"
          Action   = statement.actions
          Resource = statement.resources
        }
      ]
    )
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_all_permissions_attachment" {
  policy_arn = aws_iam_policy.codebuild_all_permissions.arn
  role       = aws_iam_role.this.name
}

# CodeBuild project
resource "aws_codebuild_project" "this" {
  name         = var.name
  service_role = aws_iam_role.this.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    dynamic "environment_variable" {
      for_each = var.environment_variables

      content {
        name  = environment_variable.key
        value = environment_variable.value
        type  = "PLAINTEXT"
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file(var.buildspec_path)
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.this.name
    }
  }
}
