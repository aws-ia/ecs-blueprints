# STATE_BUCKET=$(aws ssm get-parameters --names terraform_state_bucket | jq -r '.Parameters[0].Value')
# terraform apply -var="s3_bucket=$STATE_BUCKET"

provider "aws" {
  region = "us-west-2"
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "example" {
  bucket = var.s3_bucket
}

locals {
  terraform_state_parameter_arn = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/terraform_state_bucket"

  core_deployment_actions = [
    "ec2:AllocateAddress",
    "ec2:AssociateRouteTable",
    "ec2:AttachInternetGateway",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateInternetGateway",
    "ec2:CreateNatGateway",
    "ec2:CreateNetworkAclEntry",
    "ec2:CreateRoute",
    "ec2:CreateRouteTable",
    "ec2:CreateSubnet",
    "ec2:CreateTags",
    "ec2:CreateVpc",
    "ec2:DeleteInternetGateway",
    "ec2:DeleteNatGateway",
    "ec2:DeleteNetworkAclEntry",
    "ec2:DeleteRoute",
    "ec2:DeleteRouteTable",
    "ec2:DeleteSubnet",
    "ec2:DeleteTags",
    "ec2:DeleteVpc",
    "ec2:Describe*",
    "ec2:DetachInternetGateway",
    "ec2:DisassociateRouteTable",
    "ec2:ModifySubnetAttribute",
    "ec2:ModifyVpcAttribute",
    "ec2:ReleaseAddress",
    "ec2:ReplaceNetworkAclEntry",
    "ec2:ReplaceRouteTableAssociation",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ecs:CreateCluster",
    "ecs:DeleteCluster",
    "ecs:DescribeClusters",
    "ecs:ListAccountSettings",
    "ecs:ListTagsForResource",
    "ecs:PutClusterCapacityProviders",
    "ecs:TagResource",
    "ecs:UntagResource",
    "ecs:UpdateCluster",
    "ecs:UpdateClusterSettings",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:DescribeLogGroups",
    "logs:ListTagsForResource",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",
    # Cloud Map private DNS namespaces create and delete Route 53 hosted zones on the
    # caller's behalf, so namespace management needs these Route 53 actions.
    "route53:CreateHostedZone",
    "route53:DeleteHostedZone",
    "route53:GetChange",
    "route53:GetHostedZone",
    "route53:ListHostedZonesByName",
    "servicediscovery:CreatePrivateDnsNamespace",
    "servicediscovery:DeleteNamespace",
    "servicediscovery:GetNamespace",
    "servicediscovery:GetOperation",
    "servicediscovery:ListTagsForResource",
    "servicediscovery:TagResource",
    "servicediscovery:UntagResource",
    "servicediscovery:UpdatePrivateDnsNamespace",
  ]

  service_deployment_actions = [
    "codedeploy:CreateApplication",
    "codedeploy:CreateDeploymentGroup",
    "codedeploy:DeleteApplication",
    "codedeploy:DeleteDeploymentGroup",
    "codedeploy:GetApplication",
    "codedeploy:GetDeploymentGroup",
    "codedeploy:ListTagsForResource",
    "codedeploy:TagResource",
    "codedeploy:UntagResource",
    "codedeploy:UpdateDeploymentGroup",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateSecurityGroup",
    "ec2:CreateTags",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteTags",
    "ec2:Describe*",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ecs:CreateService",
    "ecs:DeleteService",
    "ecs:DeregisterTaskDefinition",
    "ecs:DescribeClusters",
    "ecs:DescribeServices",
    "ecs:DescribeTaskDefinition",
    "ecs:ListTagsForResource",
    "ecs:RegisterTaskDefinition",
    "ecs:TagResource",
    "ecs:UntagResource",
    "ecs:UpdateService",
    "elasticloadbalancing:AddTags",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:DeregisterTargets",
    "elasticloadbalancing:Describe*",
    "elasticloadbalancing:ModifyListener",
    "elasticloadbalancing:ModifyLoadBalancerAttributes",
    "elasticloadbalancing:ModifyTargetGroup",
    "elasticloadbalancing:ModifyTargetGroupAttributes",
    "elasticloadbalancing:RegisterTargets",
    "elasticloadbalancing:RemoveTags",
    "elasticloadbalancing:SetSecurityGroups",
    "elasticloadbalancing:SetSubnets",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:DescribeLogGroups",
    "logs:ListTagsForResource",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",
    "servicediscovery:CreateService",
    "servicediscovery:DeleteService",
    "servicediscovery:GetNamespace",
    "servicediscovery:GetOperation",
    "servicediscovery:GetService",
    # The aws_service_discovery_dns_namespace data source lists namespaces to find one by name.
    "servicediscovery:ListNamespaces",
    "servicediscovery:ListTagsForResource",
    "servicediscovery:TagResource",
    "servicediscovery:UntagResource",
    "servicediscovery:UpdateService",
    "sns:CreateTopic",
    "sns:DeleteTopic",
    "sns:GetTopicAttributes",
    "sns:ListTagsForResource",
    "sns:SetTopicAttributes",
    "sns:TagResource",
    "sns:UntagResource",
  ]
}

# CodeCommit repository
resource "aws_codecommit_repository" "example_repo" {
  repository_name = "iac_sample_repo"
}

################################################################################
# Pre-provisioned Deployment Roles
################################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "iac-pipeline-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "iac-pipeline-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role" "codedeploy" {
  name = "iac-pipeline-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSCodeDeployRoleForECS"
}

################################################################################
# CodeBuild Modules to Deploy Terraform IAC
################################################################################

module "deploy_dev_core_infra" {
  source                        = "../../modules/codebuild-iac"
  iam_role_name                 = "deploy_dev_core_infra"
  buildspec_path                = "./dev-core-infra-deploy-buildspec.yml"
  name                          = "deploy_dev_core_infra"
  artifact_bucket_arn           = data.aws_s3_bucket.example.arn
  terraform_state_parameter_arn = local.terraform_state_parameter_arn

  deployment_policy_statements = [{
    sid       = "DeployCoreInfrastructure"
    actions   = local.core_deployment_actions
    resources = ["*"]
  }]
}

module "deploy_dev_lb_service" {
  source                        = "../../modules/codebuild-iac"
  iam_role_name                 = "deploy_dev_lb_service"
  buildspec_path                = "./dev-lb-service-deploy-buildspec.yml"
  name                          = "deploy_dev_lb_service"
  artifact_bucket_arn           = data.aws_s3_bucket.example.arn
  terraform_state_parameter_arn = local.terraform_state_parameter_arn
  pass_role_arns_by_service = {
    "codedeploy.amazonaws.com" = [aws_iam_role.codedeploy.arn]
    "ecs-tasks.amazonaws.com" = [
      aws_iam_role.ecs_task.arn,
      aws_iam_role.ecs_task_execution.arn,
    ]
  }
  environment_variables = {
    TF_VAR_codedeploy_service_role_arn = aws_iam_role.codedeploy.arn
    TF_VAR_task_execution_role_arn     = aws_iam_role.ecs_task_execution.arn
    TF_VAR_task_role_arn               = aws_iam_role.ecs_task.arn
  }

  deployment_policy_statements = [{
    sid       = "DeployLoadBalancedService"
    actions   = local.service_deployment_actions
    resources = ["*"]
  }]
}

# Optional QA stage projects. Uncomment these modules together with the QA
# pipeline stages below. The QA buildspecs deploy the same roots with
# `../qa.tfvars` (us-east-1) and separate state keys, reusing the
# pre-provisioned deployment roles above.
/*
module "deploy_qa_core_infra" {
  source                        = "../../modules/codebuild-iac"
  iam_role_name                 = "deploy_qa_core_infra"
  buildspec_path                = "./qa-core-infra-deploy-buildspec.yml"
  name                          = "deploy_qa_core_infra"
  artifact_bucket_arn           = data.aws_s3_bucket.example.arn
  terraform_state_parameter_arn = local.terraform_state_parameter_arn

  deployment_policy_statements = [{
    sid       = "DeployCoreInfrastructure"
    actions   = local.core_deployment_actions
    resources = ["*"]
  }]
}

module "deploy_qa_lb_service" {
  source                        = "../../modules/codebuild-iac"
  iam_role_name                 = "deploy_qa_lb_service"
  buildspec_path                = "./qa-lb-service-deploy-buildspec.yml"
  name                          = "deploy_qa_lb_service"
  artifact_bucket_arn           = data.aws_s3_bucket.example.arn
  terraform_state_parameter_arn = local.terraform_state_parameter_arn
  pass_role_arns_by_service = {
    "codedeploy.amazonaws.com" = [aws_iam_role.codedeploy.arn]
    "ecs-tasks.amazonaws.com" = [
      aws_iam_role.ecs_task.arn,
      aws_iam_role.ecs_task_execution.arn,
    ]
  }
  environment_variables = {
    TF_VAR_codedeploy_service_role_arn = aws_iam_role.codedeploy.arn
    TF_VAR_task_execution_role_arn     = aws_iam_role.ecs_task_execution.arn
    TF_VAR_task_role_arn               = aws_iam_role.ecs_task.arn
  }

  deployment_policy_statements = [{
    sid       = "DeployLoadBalancedService"
    actions   = local.service_deployment_actions
    resources = ["*"]
  }]
}
*/

################################################################################
# CodePipeline Permissions
################################################################################

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

resource "aws_iam_role_policy" "codepipeline" {
  name = "run-iac-pipeline"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSourceRepository"
        Effect = "Allow"
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
        ]
        Resource = aws_codecommit_repository.example_repo.arn
      },
      {
        Sid    = "RunDeploymentBuilds"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ]
        Resource = [
          module.deploy_dev_core_infra.project_arn,
          module.deploy_dev_lb_service.project_arn,
        ]
      },
      {
        Sid    = "UseArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
        ]
        Resource = data.aws_s3_bucket.example.arn
      },
      {
        Sid    = "ReadWriteArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = "${data.aws_s3_bucket.example.arn}/*"
      },
    ]
  })
}

################################################################################
# CodePipeline
################################################################################

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
        BranchName     = "main" # Replace with your branch name
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
      version         = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_dev_core_infra.project_id
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
      version         = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = module.deploy_dev_lb_service.project_id
      }
    }
  }

  # Optional QA stages. Uncomment together with the deploy_qa_* modules above
  # and add module.deploy_qa_core_infra.project_arn and
  # module.deploy_qa_lb_service.project_arn to the RunDeploymentBuilds statement
  # of aws_iam_role_policy.codepipeline so the pipeline can start these builds.
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
        ProjectName = module.deploy_qa_core_infra.project_id
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
        ProjectName = module.deploy_qa_lb_service.project_id
      }
    }
  }
  # You can add more stages for deployment or testing as needed
  */
}
