resource "aws_iam_role" "ecs_task_excecution_role" {
  count              = var.create_ecs_role == true ? 1 : 0
  name               = var.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name = var.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ecs_task_role" {
  count              = var.create_ecs_role == true ? 1 : 0
  name               = var.name_ecs_task_role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name = var.name_ecs_task_role
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_iam_role" "devops_role" {
  count              = var.create_devops_role == true ? 1 : 0
  name               = var.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com",
          "codedeploy.amazonaws.com",
          "codepipeline.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "codedeploy_role" {
  count              = var.create_codedeploy_role == true ? 1 : 0
  name               = var.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

# ------- IAM Policies -------
resource "aws_iam_policy" "policy_for_role" {
  count       = var.create_devops_policy == true ? 1 : 0
  name        = "Policy-${var.name}"
  description = "IAM Policy for Role ${var.name}"
  policy      = data.aws_iam_policy_document.role_policy_devops_role.json

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "policy_for_ecs_task_role" {
  count       = var.create_ecs_role == true ? 1 : 0
  name        = "Policy-${var.name_ecs_task_role}"
  description = "IAM Policy for Role ${var.name_ecs_task_role}"
  policy      = data.aws_iam_policy_document.role_policy_ecs_task_role.json

  lifecycle {
    create_before_destroy = true
  }
}

# ------- IAM Policies Attachments -------
resource "aws_iam_role_policy_attachment" "ecs_attachment" {
  count      = var.create_ecs_role == true ? 1 : 0
  policy_arn = aws_iam_policy.policy_for_ecs_task_role[0].arn
  role       = aws_iam_role.ecs_task_role[0].name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "attachment" {
  count      = length(aws_iam_role.ecs_task_excecution_role) > 0 ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_excecution_role[0].name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "attachment2" {
  count      = var.create_devops_policy == true ? 1 : 0
  policy_arn = aws_iam_policy.policy_for_role[0].arn
  role       = var.attach_to

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_attachment" {
  count      = var.create_codedeploy_role == true ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codedeploy_role[0].name
}

# ------- IAM Policy Documents -------
data "aws_iam_policy_document" "role_policy_devops_role" {
  statement {
    sid    = "AllowS3Actions"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:List*"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCodebuildActions"
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetBuildBatches",
      "codebuild:StartBuildBatch",
      "codebuild:StopBuild"
    ]
    resources = var.code_build_projects
  }
  statement {
    sid    = "AllowCodebuildList"
    effect = "Allow"
    actions = [
      "codebuild:ListBuilds"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCodeDeployActions"
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:RegisterApplicationRevision"
    ]
    resources = var.code_deploy_resources
  }
  statement {
    sid    = "AllowCodeDeployConfigs"
    effect = "Allow"
    actions = [
      "codedeploy:GetDeploymentConfig",
      "codedeploy:CreateDeploymentConfig",
      "codedeploy:CreateDeploymentGroup",
      "codedeploy:GetDeploymentTarget",
      "codedeploy:StopDeployment",
      "codedeploy:ListApplications",
      "codedeploy:ListDeploymentConfigs",
      "codedeploy:ListDeploymentGroups",
      "codedeploy:Listdeployments"

    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowECRActions"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = var.ecr_repositories
  }
  statement {
    sid    = "AllowECRAuthorization"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCECSServiceActions"
    effect = "Allow"
    actions = [
      "ecs:ListServices",
      "ecs:ListTasks",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTaskSets",
      "ecs:DeleteTaskSet",
      "ecs:DeregisterContainerInstance",
      "ecs:CreateTaskSet",
      "ecs:UpdateCapacityProvider",
      "ecs:PutClusterCapacityProviders",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:StopTask",
      "ecs:UpdateService",
      "ecs:UpdateCluster",
      "ecs:UpdateTaskSet"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCloudWatchActions"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "role_policy_ecs_task_role" {
  statement {
    sid    = "AllowS3Actions"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = var.s3_bucket_assets
  }
  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowDynamodbActions"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = var.dynamodb_table
  }
}
