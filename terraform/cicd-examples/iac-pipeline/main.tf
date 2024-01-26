# STATE_BUCKET=$(aws ssm get-parameters --names terraform_state_bucket | jq -r '.Parameters[0].Value')
# terraform apply -var="s3_bucket=$STATE_BUCKET"

provider "aws" {
  region = "us-west-2"
}

data "aws_s3_bucket" "example" {
  bucket = var.s3_bucket
}

# CodeCommit repository
resource "aws_codecommit_repository" "example_repo" {
  repository_name = "iac_sample_repo"
}

module "deploy_dev_core_infra" {
  source = "../../modules/codebuild-iac"
  iam_role_name = "deploy_dev_core_infra"
  buildspec_path = "./dev-core-infra-deploy-buildspec.yml"
  s3_bucket_name = data.aws_s3_bucket.example.id
  name = "deploy_dev_core_infra"
}

module "deploy_dev_lb_service" {
  source = "../../modules/codebuild-iac"
  iam_role_name = "deploy_dev_lb_service"
  buildspec_path = "./dev-lb-service-deploy-buildspec.yml"
  s3_bucket_name = data.aws_s3_bucket.example.id
  name = "deploy_dev_lb_service"
}

/*
module "deploy_qa_core_infra" {
  source = "../../modules/codebuild-iac"
  iam_role_name = "deploy_qa_core_infra"
  buildspec_path = "./qa-core-infra-deploy-buildspec.yml"
  s3_bucket_name = data.aws_s3_bucket.example.id
  name = "deploy_qa_core_infra"
}

module "deploy_qa_lb_service" {
  source = "../../modules/codebuild-iac"
  iam_role_name = "deploy_qa_lb_service"
  buildspec_path = "./qa-lb-service-deploy-buildspec.yml"
  s3_bucket_name = data.aws_s3_bucket.example.id
  name = "deploy_qa_lb_service"
}
*/

#IAM role for Code Pipeline 
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  
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

resource "aws_iam_role_policy_attachment" "vpc_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_codepipeline_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"  # Attach a policy that provides necessary permissions
  role       = aws_iam_role.codepipeline_role.name
}

# CodePipeline
resource "aws_codepipeline" "example_pipeline" {
  name     = "example-iac-pipeline"
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
    name = "core-infra-dev"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version          = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_dev_core_infra.ProjectName
      }
    }
  }
  
  stage {
    name = "lb-service-dev"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version          = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_dev_lb_service.ProjectName
      }
    }
  }

 /*
  stage {
    name = "ManualApprovalToQA"

    action {
      name     = "ManualApprovalToQAAction"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version          = "1"
    }
  }

  stage {
    name = "core-infra-qa"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version          = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_qa_core_infra.ProjectName
      }
    }
  }

  stage {
    name = "lb-service-qa"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version          = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_qa_lb_service.ProjectName
      }
    }
  }
  # You can add more stages for deployment or testing as needed
  */
}
