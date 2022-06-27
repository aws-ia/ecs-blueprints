provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "id_current_account" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

# ------- Creating Target Group for the server ALB -------
module "target_group_server" {
  source = "./../../../modules/alb"

  create_target_group = true

  name              = "tg-${local.name}-s"
  port              = 80
  protocol          = "HTTP"
  vpc               = module.vpc.vpc_id
  tg_type           = "ip"
  health_check_path = "/status"
  health_check_port = var.port_app_server

  tags = local.tags
}

# ------- Creating Target Group for the client ALB -------
module "target_group_client" {
  source = "./../../../modules/alb"

  create_target_group = true

  name              = "tg-${local.name}-c"
  port              = 80
  protocol          = "HTTP"
  vpc               = module.vpc.vpc_id
  tg_type           = "ip"
  health_check_path = "/"
  health_check_port = var.port_app_client

  tags = local.tags
}

# ------- Creating Security Group for the server ALB -------
module "security_group_alb_server" {
  source = "./../../../modules/security_group"

  name                = "alb-${local.name}-server"
  description         = "Controls access to the server ALB"
  vpc_id              = module.vpc.vpc_id
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Security Group for the client ALB -------
module "security_group_alb_client" {
  source = "./../../../modules/security_group"

  name                = "alb-${local.name}-client"
  description         = "Controls access to the client ALB"
  vpc_id              = module.vpc.vpc_id
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Server Application ALB -------
module "alb_server" {
  source = "./../../../modules/alb"

  create_alb = true

  name           = "${local.name}-server"
  subnets        = module.vpc.public_subnets
  security_group = module.security_group_alb_server.sg_id
  target_group   = module.target_group_server.arn_tg

  tags = local.tags
}

# ------- Creating Client Application ALB -------
module "alb_client" {
  source = "./../../../modules/alb"

  create_alb = true

  name           = "${local.name}-client"
  subnets        = module.vpc.public_subnets
  security_group = module.security_group_alb_client.sg_id
  target_group   = module.target_group_client.arn_tg

  tags = local.tags
}

# ------- ECS Role -------
module "ecs_role" {
  source = "./../../../modules/iam"

  create_ecs_role = true

  name               = var.iam_role_name["ecs"]
  name_ecs_task_role = var.iam_role_name["ecs_task_role"]
  dynamodb_table     = [module.dynamodb_table.dynamodb_table_arn]
}

# ------- Creating a IAM Policy for role -------
module "ecs_role_policy" {
  source = "./../../../modules/iam"

  name      = "ecs-ecr-${local.name}"
  attach_to = module.ecs_role.name_role
}

# ------- Creating server ECR Repository to store Docker Images -------
module "ecr_server" {
  source = "./../../../modules/ecr"

  name                 = "repo-server"
  image_tag_mutability = "MUTABLE"

  tags = local.tags
}

# ------- Creating client ECR Repository to store Docker Images -------
module "ecr_client" {
  source = "./../../../modules/ecr"

  name                 = "repo-client"
  image_tag_mutability = "MUTABLE"

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/ecs/task-definition-${var.ecs_service_name["client"]}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "server" {
  name              = "/ecs/task-definition-${var.ecs_service_name["server"]}"
  retention_in_days = 30
}

# ------- Creating ECS Task Definition for the server -------
module "ecs_taks_definition_server" {
  source = "./../../../modules/ecs/task-definition"

  name                 = var.ecs_service_name["server"]
  container_name       = var.container_name["server"]
  execution_role       = module.ecs_role.arn_role
  task_role            = module.ecs_role.arn_role_ecs_task_role
  cpu                  = 256
  memory               = 512
  image                = module.ecr_server.ecr_repository_url
  region               = local.region
  container_port       = var.port_app_server
  cloudwatch_log_group = aws_cloudwatch_log_group.server.name
}

# ------- Creating ECS Task Definition for the client -------
module "ecs_taks_definition_client" {
  source = "./../../../modules/ecs/task-definition"

  name                 = var.ecs_service_name["client"]
  container_name       = var.container_name["client"]
  execution_role       = module.ecs_role.arn_role
  task_role            = module.ecs_role.arn_role_ecs_task_role
  cpu                  = 256
  memory               = 512
  image                = module.ecr_client.ecr_repository_url
  region               = local.region
  container_port       = var.port_app_client
  cloudwatch_log_group = aws_cloudwatch_log_group.client.name
}

# ------- Creating a server Security Group for ECS TASKS -------
module "security_group_ecs_task_server" {
  source = "./../../../modules/security_group"

  name            = "ecs-task-${local.name}-server"
  description     = "Controls access to the server ECS task"
  vpc_id          = module.vpc.vpc_id
  ingress_port    = var.port_app_server
  security_groups = [module.security_group_alb_server.sg_id]
}
# ------- Creating a client Security Group for ECS TASKS -------
module "security_group_ecs_task_client" {
  source = "./../../../modules/security_group"

  name            = "ecs-task-${local.name}-client"
  description     = "Controls access to the client ECS task"
  vpc_id          = module.vpc.vpc_id
  ingress_port    = var.port_app_client
  security_groups = [module.security_group_alb_client.sg_id]
}

# ------- Creating ECS Service server -------
module "ecs_service_server" {
  source = "./../../../modules/ecs/service"

  name            = var.ecs_service_name["server"]
  desired_count   = var.ecs_desired_tasks["server"]
  security_groups = [module.security_group_ecs_task_server.sg_id]
  ecs_cluster_id  = var.ecs_cluster_id
  load_balancers = [{
    container_name   = var.container_name["server"]
    container_port   = var.port_app_server
    target_group_arn = module.target_group_server.arn_tg
  }]
  task_definition                    = module.ecs_taks_definition_server.task_definition_arn
  subnets                            = module.vpc.private_subnets
  deployment_maximum_percent         = var.deployment_maximum_percent["server"]
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent["server"]
  health_check_grace_period_seconds  = var.seconds_health_check_grace_period
  deployment_controller              = "ECS"

  tags = local.tags
}

# ------- Creating ECS Service client -------
module "ecs_service_client" {
  source = "./../../../modules/ecs/service"

  name            = var.ecs_service_name["client"]
  desired_count   = var.ecs_desired_tasks["client"]
  security_groups = [module.security_group_ecs_task_client.sg_id]
  ecs_cluster_id  = var.ecs_cluster_id
  load_balancers = [{
    container_name   = var.container_name["client"]
    container_port   = var.port_app_client
    target_group_arn = module.target_group_client.arn_tg
  }]
  task_definition                    = module.ecs_taks_definition_client.task_definition_arn
  subnets                            = module.vpc.private_subnets
  deployment_maximum_percent         = var.deployment_maximum_percent["client"]
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent["client"]
  health_check_grace_period_seconds  = var.seconds_health_check_grace_period
  deployment_controller              = "ECS"

  tags = local.tags
}

# ------- Creating ECS Autoscaling policies for the server application -------
module "ecs_autoscaling_server" {
  source = "./../../../modules/ecs/autoscaling"

  service_name     = var.ecs_service_name["server"]
  cluster_name     = var.ecs_cluster_name
  min_capacity     = var.ecs_autoscaling_min_capacity["server"]
  max_capacity     = var.ecs_autoscaling_max_capacity["server"]
  cpu_threshold    = var.cpu_threshold["server"]
  memory_threshold = var.memory_threshold["server"]
}

# ------- Creating ECS Autoscaling policies for the client application -------
module "ecs_autoscaling_client" {
  source = "./../../../modules/ecs/autoscaling"

  service_name     = var.ecs_service_name["client"]
  cluster_name     = var.ecs_cluster_name
  min_capacity     = var.ecs_autoscaling_min_capacity["client"]
  max_capacity     = var.ecs_autoscaling_max_capacity["client"]
  cpu_threshold    = var.cpu_threshold["client"]
  memory_threshold = var.memory_threshold["client"]
}

# ------- CodePipeline -------

# ------- Creating Bucket to store CodePipeline artifacts -------
module "s3_codepipeline" {
  source = "./../../../modules/s3"

  bucket_name = "codepipeline-${local.region}-${random_id.this.hex}"
}

# ------- Creating IAM roles used during the pipeline excecution -------
module "devops_role" {
  source = "./../../../modules/iam"

  create_devops_role = true
  name               = var.iam_role_name["devops"]
}

# ------- Creating an IAM Policy for role -------
module "policy_devops_role" {
  source = "./../../../modules/iam"

  create_devops_policy = true

  name                = "devops-${local.name}"
  attach_to           = module.devops_role.name_role
  ecr_repositories    = [module.ecr_server.ecr_repository_arn, module.ecr_client.ecr_repository_arn]
  code_build_projects = [module.codebuild_client.project_arn, module.codebuild_server.project_arn]
}

# ------- Creating a SNS topic -------
module "sns" {
  source = "./../../../modules/sns"

  sns_name = "sns-${local.name}"
}

# ------- Creating the server CodeBuild project -------
module "codebuild_server" {
  source = "./codebuild"

  name                   = "codebuild-${local.name}-server"
  iam_role               = module.devops_role.arn_role
  region                 = local.region
  account_id             = data.aws_caller_identity.id_current_account.account_id
  ecr_repo_url           = module.ecr_server.ecr_repository_url
  folder_path            = var.folder_path_server
  buildspec_path         = var.buildspec_path
  task_definition_family = module.ecs_taks_definition_server.task_definition_family
  container_name         = var.container_name["server"]
  service_port           = var.port_app_server
  ecs_role               = var.iam_role_name["ecs"]
  ecs_task_role          = var.iam_role_name["ecs_task_role"]
  dynamodb_table_name    = module.dynamodb_table.dynamodb_table_name
}

# ------- Creating the client CodeBuild project -------
module "codebuild_client" {
  source = "./codebuild"

  name                   = "codebuild-${local.name}-client"
  iam_role               = module.devops_role.arn_role
  region                 = local.region
  account_id             = data.aws_caller_identity.id_current_account.account_id
  ecr_repo_url           = module.ecr_client.ecr_repository_url
  folder_path            = var.folder_path_client
  buildspec_path         = var.buildspec_path
  task_definition_family = module.ecs_taks_definition_client.task_definition_family
  container_name         = var.container_name["client"]
  service_port           = var.port_app_client
  ecs_role               = var.iam_role_name["ecs"]
  server_alb_url         = module.alb_server.dns_alb
}

# ------- Creating CodePipeline -------
module "codepipeline" {
  source = "./codepipeline"

  name                     = "pipeline-${local.name}"
  pipe_role                = module.devops_role.arn_role
  s3_bucket                = module.s3_codepipeline.s3_bucket_id
  github_token             = var.github_token
  repo_owner               = var.repository_owner
  repo_name                = var.repository_name
  branch                   = var.repository_branch
  codebuild_project_server = module.codebuild_server.project_id
  codebuild_project_client = module.codebuild_client.project_id
  ecs_cluster_name         = var.ecs_cluster_name
  ecs_service_name_client  = var.ecs_service_name["client"]
  ecs_service_name_server  = var.ecs_service_name["server"]
  depends_on               = [module.policy_devops_role]
  sns_topic                = module.sns.sns_arn
}

# ------- Creating Bucket to store assets accessed by the Back-end -------
module "s3_assets" {
  source = "./../../../modules/s3"

  bucket_name = "assets-${local.region}-${random_id.this.hex}"
}

# ------- Creating Dynamodb table by the Back-end -------
module "dynamodb_table" {
  source = "./../../../modules/dynamodb"

  name = "assets-table-${local.name}"
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  tags = local.tags
}

resource "random_id" "this" {
  byte_length = "2"
}
