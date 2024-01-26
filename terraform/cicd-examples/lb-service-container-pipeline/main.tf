data "aws_partition" "current" {}

data "aws_s3_bucket" "example" {
  bucket = var.s3_bucket
}

################################################################################
# Parameter Store
################################################################################

# CodeDeploy Application Parameter
data "aws_ssm_parameter" "codedeploy_app" {
  name  = "/codedeploy/app/deploy_development_ecsdemo-frontend"
}

# CodeDeploy Deployment Group Parameter
data "aws_ssm_parameter" "deployment_group" {
  name  = "/codedeploy/deployment-group/deploy_development_ecsdemo-frontend"
}

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

#IAM role for Code Pipeline 
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
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

#IAM role for Code Build to ECR 
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
  #policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"  # Attach a policy that provides necessary permissions
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.codebuild_role.name
}

module "build_container" {
  source = "../../modules/codebuild"  # Path to module folder
  name = "dev-lb-service-build"
  create_iam_role = true
  s3_bucket = data.aws_s3_bucket.example.id
  buildspec_path = "../../../application-code/ecsdemo-cicd/buildspec.yml"
  ecr_repository = aws_ecr_repository.example_repo.arn
  ecr_repository_url = aws_ecr_repository.example_repo.repository_url
  service_role = aws_iam_role.codebuild_role.arn
  iam_role_name = "dev-lb-service-build"  
}

# CodePipeline
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
        BranchName     = "main"  # Replace with your branch name
      }
    }
  }

  stage {
    name = "build-lb-service"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version          = "1"
      input_artifacts = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = module.build_container.ProjectName
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
            ApplicationName  = data.aws_ssm_parameter.codedeploy_app.value
            DeploymentGroupName = data.aws_ssm_parameter.deployment_group.value
            TaskDefinitionTemplateArtifact = "BuildArtifact"
            TaskDefinitionTemplatePath = "development-task-definition.json"
            AppSpecTemplateArtifact = "BuildArtifact"
            AppSpecTemplatePath = "development-appspec.json.json"
        }
      }
    }

  # You can add more stages for deployment or testing as needed
}
