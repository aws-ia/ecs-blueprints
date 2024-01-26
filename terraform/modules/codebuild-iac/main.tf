

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

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "vpc_codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ecs_codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ec2_ccodebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.this.name
}

# CodeBuild project
resource "aws_codebuild_project" "this" {
  name = var.name
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
    type = "CODEPIPELINE"
    buildspec = file(var.buildspec_path)
  }

}