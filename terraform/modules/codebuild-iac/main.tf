

# IAM role for role for code build
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

resource "aws_iam_policy" "codebuild_all_permissions" {
  description = "IAM policy for AWS CodeBuild with all necessary permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "codebuild:*",
          "codedeploy:*",
          "codepipeline:*",
          "ec2:*",
          "ecs:*",
          "elasticloadbalancing:*",
          "iam:AttachRolePolicy",
          "iam:CreatePolicy",
          "iam:CreateRole",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListGroupPolicies",
          "iam:ListGroups",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole",
          "iam:ListPolicies",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:TagPolicy",
          "logs:*",
          "route53:*",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:PutObject",
          "servicediscovery:*",
          "sns:*",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListTagsForResource",
          "ssm:PutParameter"
        ],
        Resource = "*",
      },
    ],
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
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file(var.buildspec_path)
  }

}
