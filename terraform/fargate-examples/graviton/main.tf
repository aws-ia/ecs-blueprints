provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "nodejs-multi-arch"
  region = "us-west-2"

  container_port = 3000 # Container port is specific to this app example
  container_name = "nodejs-multi-arch"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.repository_owner}/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "container_image_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = local.container_name

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)]
  repository_read_write_access_arns = [module.codepipeline_ci_cd.codepipeline_role_arn]

  tags = local.tags
}

module "service_alb_amd64" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.3"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids
  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]
    }
  }

  http_tcp_listeners = [
    {
      port               = "80"
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tg"
      backend_protocol = "HTTP"
      backend_port     = local.container_port
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = local.container_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

module "service_alb_arm64" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.3"

  name = "${local.name}-arm-alb"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.vpc.id
  subnets = data.aws_subnets.public.ids
  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]
    }
  }

  http_tcp_listeners = [
    {
      port               = "80"
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-arm-tg"
      backend_protocol = "HTTP"
      backend_port     = local.container_port
      target_type      = "ip"
      health_check = {
        path    = "/"
        port    = local.container_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

resource "aws_service_discovery_service" "amd64" {
  name = local.name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "arm64" {
  name = "${local.name}-arm64"

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

module "ecs_service_definition_amd64" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name          = local.name
  desired_count = 3
  cluster_arn   = data.aws_ecs_cluster.core_infra.arn

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_alb_service = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.service_alb_amd64.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  load_balancer = [{
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = element(module.service_alb_amd64.target_group_arns, 0)
  }]

  service_registries = {
    registry_arn = aws_service_discovery_service.amd64.arn
  }

  # Task Definition
  create_iam_role        = false
  task_exec_iam_role_arn = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command = true

  container_definitions = {
    main_container = {
      name                     = local.container_name
      image                    = module.container_image_ecr.repository_url
      readonly_root_filesystem = false

      port_mappings = [{
        protocol : "tcp",
        containerPort : local.container_port
        hostPort : local.container_port
      }]
    }
  }

  tags = local.tags
}

module "ecs_service_definition_arm64" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name          = "${local.name}-arm64"
  desired_count = 3
  cluster_arn   = data.aws_ecs_cluster.core_infra.arn

  subnet_ids = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_alb_service = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = module.service_alb_arm64.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  load_balancer = [{
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = element(module.service_alb_arm64.target_group_arns, 0)
  }]

  service_registries = {
    registry_arn = aws_service_discovery_service.arm64.arn
  }

  # Task Definition
  create_iam_role        = false
  task_exec_iam_role_arn = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
  enable_execute_command = true

  runtime_platform = {
    cpu_architecture = "ARM64"
  }

  container_definitions = {
    main_container = {
      name                     = local.container_name
      image                    = module.container_image_ecr.repository_url
      readonly_root_filesystem = false
      port_mappings = [{
        protocol : "tcp",
        containerPort : local.container_port
        hostPort : local.container_port
      }]
    }
  }

  tags = local.tags
}

################################################################################
# CodePipeline and CodeBuild for CI/CD
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "codepipeline-${local.region}-${random_id.this.hex}"

  # For example only - please re-evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_sns_topic" "codestar_notification" {
  name = local.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteAccess"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${local.region}:${data.aws_caller_identity.current.account_id}:${local.name}"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

module "codebuild_ci_amd64" {
  source = "../../modules/codebuild"

  name           = "codebuild-amd64-${module.ecs_service_definition_amd64.name}"
  service_role   = module.codebuild_ci_amd64.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.container_image_ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_definition_amd64.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
        }, {
        name  = "IMG_SUFFIX_ARCH"
        value = "amd64"
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-amd64-${random_id.this.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

module "codebuild_ci_arm64" {
  source = "../../modules/codebuild"

  name           = "codebuild-arm-${module.ecs_service_definition_arm64.name}"
  service_role   = module.codebuild_ci_arm64.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    compute_type    = "BUILD_GENERAL1_LARGE"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
    type            = "ARM_CONTAINER"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.container_image_ecr.repository_url
        }, {
        name  = "TASK_DEFINITION_FAMILY"
        value = module.ecs_service_definition_arm64.task_definition_family
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
        }, {
        name  = "IMG_SUFFIX_ARCH"
        value = "arm64v8"
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-arm-${random_id.this.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

module "codebuild_ci_manifest" {
  source = "../../modules/codebuild"

  name           = "codebuild-manifest-${local.name}"
  service_role   = module.codebuild_ci_manifest.codebuild_role_arn
  buildspec_path = "./application-code/nodejs-demoapp/templates/buildspec_manifest.yml"
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.container_image_ecr.repository_url
        }, {
        name  = "CONTAINER_NAME"
        value = local.container_name
        }, {
        name  = "SERVICE_PORT"
        value = local.container_port
        }, {
        name  = "FOLDER_PATH"
        value = "./application-code/nodejs-demoapp/."
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
      }
    ]
  }

  create_iam_role = true
  iam_role_name   = "${local.name}-cb-manifest-${random_id.this.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

module "codepipeline_ci_cd" {
  source = "../../modules/codepipeline"

  name         = "pipeline-${local.name}"
  service_role = module.codepipeline_ci_cd.codepipeline_role_arn
  s3_bucket    = module.codepipeline_s3_bucket
  sns_topic    = aws_sns_topic.codestar_notification.arn

  stage = [{
    name = "Source"
    action = [{
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["SourceArtifact"]
      configuration = {
        OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
        Owner                = var.repository_owner
        Repo                 = var.repository_name
        Branch               = var.repository_branch
        PollForSourceChanges = true
      }
    }],
    }, {
    name = "Build_image"
    action = [{
      name            = "Build_app_amd64"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = module.codebuild_ci_amd64.project_id
      }
      }, {
      name            = "Build_app_arm64"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = module.codebuild_ci_arm64.project_id
      }
    }],
    }, {
    name = "Build_manifest"
    action = [{
      name             = "Build_manifest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]
      configuration = {
        ProjectName = module.codebuild_ci_manifest.project_id
      }
    }],
    }, {
    name = "Deploy"
    action = [{
      name            = "Deploy_amd64"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_definition_amd64.name
        FileName    = "imagedefinition.json"
      }
      }, {
      name            = "Deploy_arm64"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact_app"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
        ServiceName = module.ecs_service_definition_arm64.name
        FileName    = "imagedefinition.json"
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${local.name}-pipeline-${random_id.this.hex}"

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-public-*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}

data "aws_iam_roles" "ecs_core_infra_exec_role" {
  name_regex = "core-infra-*"
}

data "aws_service_discovery_dns_namespace" "this" {
  name = "default.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}
