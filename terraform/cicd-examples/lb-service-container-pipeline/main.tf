provider "aws" {
  region = var.region
}

data "aws_s3_bucket" "example" {
  bucket = var.s3_bucket
}

################################################################################
# Parameter Store
################################################################################

# CodeDeploy Application Parameter
data "aws_ssm_parameter" "codedeploy_app" {
  name = "/codedeploy/app/deploy_development_ecsdemo-frontend"
}

# CodeDeploy Deployment Group Parameter
data "aws_ssm_parameter" "deployment_group" {
  name = "/codedeploy/deployment-group/deploy_development_ecsdemo-frontend"
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

resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "codecommit_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "s3_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "codebuild_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}


resource "aws_iam_role_policy_attachment" "codedeploy_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployDeployerAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
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

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codebuild_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codebuild_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_codebuild_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess" # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codebuild_role.name
}

resource "aws_iam_policy" "codebuild_all_permissions" {
  description = "IAM policy for AWS CodeBuild with all necessary permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource",
          "ssm:DeleteParameter",
          "logs:*",
          "ec2:*",
          "ecs:*",
          "iam:PassRole",
          "servicediscovery:*",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "codebuild:*",
          "codedeploy:*",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_all_permissions_attachment" {
  policy_arn = aws_iam_policy.codebuild_all_permissions.arn
  role       = aws_iam_role.codebuild_role.name
}

################################################################################
# CodeBuild Module
################################################################################

resource "random_id" "this" {
  byte_length = 8
}

module "build_container" {
  source = "../../modules/codebuild"

  name           = "dev-lb-service-codebuild"
  service_role   = aws_iam_role.codebuild_role.arn
  buildspec_path = "../../../application-code/ecsdemo-cicd/buildspec.yml"
  s3_bucket      = data.aws_s3_bucket.example.id

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

  create_iam_role = true
  iam_role_name   = "dev-lb-service-build-codebuild-${random_id.this.hex}"
  ecr_repository  = aws_ecr_repository.example_repo.arn
}

################################################################################
# CodePipeline
################################################################################

resource "aws_codepipeline" "example_applicaiton_pipeline" {
  name     = "example-applicaiton-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = data.aws_s3_bucket.example.bucket
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
        ApplicationName                = data.aws_ssm_parameter.codedeploy_app.value
        DeploymentGroupName            = data.aws_ssm_parameter.deployment_group.value
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "development-task-definition.json"
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "development-appspec.json.json"
      }
    }
  }

  # You can add more stages for deployment or testing as needed
}
