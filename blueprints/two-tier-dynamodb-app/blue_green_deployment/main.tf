# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*===========================
          Root file
============================*/

# ------- Providers -------
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# ------- Random numbers intended to be used as unique identifiers for resources -------
resource "random_id" "RANDOM_ID" {
  byte_length = "2"
}

# ------- Account ID -------
data "aws_caller_identity" "id_current_account" {}

# ------- Creating Target Group for the server ALB blue environment -------
module "target_group_server_blue" {
  source              = "./../../../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-s-b"
  port                = 80
  protocol            = "HTTP"
  vpc                 = var.vpc
  tg_type             = "ip"
  health_check_path   = "/status"
  health_check_port   = var.port_app_server
}

# ------- Creating Target Group for the server ALB green environment -------
module "target_group_server_green" {
  source              = "./../../../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-s-g"
  port                = 80
  protocol            = "HTTP"
  vpc                 = var.vpc
  tg_type             = "ip"
  health_check_path   = "/status"
  health_check_port   = var.port_app_server
}

# ------- Creating Target Group for the client ALB blue environment -------
module "target_group_client_blue" {
  source              = "./../../../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-c-b"
  port                = 80
  protocol            = "HTTP"
  vpc                 = var.vpc
  tg_type             = "ip"
  health_check_path   = "/"
  health_check_port   = var.port_app_client
}

# ------- Creating Target Group for the client ALB green environment -------
module "target_group_client_green" {
  source              = "./../../../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-c-g"
  port                = 80
  protocol            = "HTTP"
  vpc                 = var.vpc
  tg_type             = "ip"
  health_check_path   = "/"
  health_check_port   = var.port_app_client
}

# ------- Creating Security Group for the server ALB -------
module "security_group_alb_server" {
  source              = "./../../../modules/security_group"
  name                = "alb-${var.environment_name}-server"
  description         = "Controls access to the server ALB"
  vpc_id              = var.vpc
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Security Group for the client ALB -------
module "security_group_alb_client" {
  source              = "./../../../modules/security_group"
  name                = "alb-${var.environment_name}-client"
  description         = "Controls access to the client ALB"
  vpc_id              = var.vpc
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Server Application ALB -------
module "alb_server" {
  source         = "./../../../modules/alb"
  create_alb     = true
  name           = "${var.environment_name}-ser"
  subnets        = [var.public_subnets[0], var.public_subnets[1]]
  security_group = module.security_group_alb_server.sg_id
  target_group   = module.target_group_server_blue.arn_tg
}

# ------- Creating Client Application ALB -------
module "alb_client" {
  source         = "./../../../modules/alb"
  create_alb     = true
  name           = "${var.environment_name}-cli"
  subnets        = [var.public_subnets[0], var.public_subnets[1]]
  security_group = module.security_group_alb_client.sg_id
  target_group   = module.target_group_client_blue.arn_tg
}

# ------- ECS Role -------
module "ecs_role" {
  source             = "./../../../modules/iam"
  create_ecs_role    = true
  name               = var.iam_role_name["ecs"]
  name_ecs_task_role = var.iam_role_name["ecs_task_role"]
  dynamodb_table     = [module.dynamodb_table.dynamodb_table_arn]
}

# ------- Creating a IAM Policy for role -------
module "ecs_role_policy" {
  source        = "./../../../modules/iam"
  name          = "ecs-ecr-${var.environment_name}"
  create_policy = true
  attach_to     = module.ecs_role.name_role
}

# ------- Creating server ECR Repository to store Docker Images -------
module "ecr_server" {
  source = "./../../../modules/ecr"
  name   = "repo-server"
}

# ------- Creating client ECR Repository to store Docker Images -------
module "ecr_client" {
  source = "./../../../modules/ecr"
  name   = "repo-client"
}

# ------- Creating ECS Task Definition for the server -------
module "ecs_taks_definition_server" {
  source             = "./../../../modules/ecs/task_definition"
  name               = var.ecs_service_name["server"]
  container_name     = var.container_name["server"]
  execution_role_arn = module.ecs_role.arn_role
  task_role_arn      = module.ecs_role.arn_role_ecs_task_role
  cpu                = var.ecs_task_server_cpu
  memory             = var.ecs_task_server_memory
  docker_repo        = module.ecr_server.ecr_repository_url
  region             = var.aws_region
  container_port     = var.port_app_server
}

# ------- Creating ECS Task Definition for the client -------
module "ecs_taks_definition_client" {
  source             = "./../../../modules/ecs/task_definition"
  name               = var.ecs_service_name["client"]
  container_name     = var.container_name["client"]
  execution_role_arn = module.ecs_role.arn_role
  task_role_arn      = module.ecs_role.arn_role_ecs_task_role
  cpu                = var.ecs_task_client_cpu
  memory             = var.ecs_task_client_memory
  docker_repo        = module.ecr_client.ecr_repository_url
  region             = var.aws_region
  container_port     = var.port_app_client
}

# ------- Creating a server Security Group for ECS TASKS -------
module "security_group_ecs_task_server" {
  source          = "./../../../modules/security_group"
  name            = "ecs-task-${var.environment_name}-server"
  description     = "Controls access to the server ECS task"
  vpc_id          = var.vpc
  ingress_port    = var.port_app_server
  security_groups = [module.security_group_alb_server.sg_id]
}
# ------- Creating a client Security Group for ECS TASKS -------
module "security_group_ecs_task_client" {
  source          = "./../../../modules/security_group"
  name            = "ecs-task-${var.environment_name}-client"
  description     = "Controls access to the client ECS task"
  vpc_id          = var.vpc
  ingress_port    = var.port_app_client
  security_groups = [module.security_group_alb_client.sg_id]
}

# ------- Creating ECS Service server -------
module "ecs_service_server" {
  depends_on                         = [module.alb_server]
  source                             = "./../../../modules/ecs/service"
  name                               = var.ecs_service_name["server"]
  desired_tasks                      = var.ecs_desired_tasks["server"]
  arn_security_group                 = module.security_group_ecs_task_server.sg_id
  ecs_cluster_id                     = var.ecs_cluster_id
  arn_target_group                   = module.target_group_server_blue.arn_tg
  arn_task_definition                = module.ecs_taks_definition_server.arn_task_definition
  subnets_id                         = [var.private_subnets_server[0], var.private_subnets_server[1]]
  container_port                     = var.port_app_server
  container_name                     = var.container_name["server"]
  seconds_health_check_grace_period  = var.seconds_health_check_grace_period
  deployment_controller              = "CODE_DEPLOY"
  deployment_minimum_healthy_percent = null
  deployment_maximum_percent         = null
}

# ------- Creating ECS Service client -------
module "ecs_service_client" {
  depends_on                         = [module.alb_client]
  source                             = "./../../../modules/ecs/service"
  name                               = var.ecs_service_name["client"]
  desired_tasks                      = var.ecs_desired_tasks["client"]
  arn_security_group                 = module.security_group_ecs_task_client.sg_id
  ecs_cluster_id                     = var.ecs_cluster_id
  arn_target_group                   = module.target_group_client_blue.arn_tg
  arn_task_definition                = module.ecs_taks_definition_client.arn_task_definition
  subnets_id                         = [var.private_subnets_client[0], var.private_subnets_client[1]]
  container_port                     = var.port_app_client
  container_name                     = var.container_name["client"]
  seconds_health_check_grace_period  = var.seconds_health_check_grace_period
  deployment_controller              = "CODE_DEPLOY"
  deployment_minimum_healthy_percent = null
  deployment_maximum_percent         = null
}

# ------- Creating ECS Autoscaling policies for the server application -------
module "ecs_autoscaling_server" {
  depends_on       = [module.ecs_service_server]
  source           = "./../../../modules/ecs/autoscaling"
  name             = "${var.environment_name}-server"
  cluster_name     = var.ecs_cluster_name
  min_capacity     = var.ecs_autoscaling_min_capacity["server"]
  max_capacity     = var.ecs_autoscaling_max_capacity["server"]
  cpu_threshold    = var.cpu_threshold["server"]
  memory_threshold = var.memory_threshold["server"]
}

# ------- Creating ECS Autoscaling policies for the client application -------
module "ecs_autoscaling_client" {
  depends_on       = [module.ecs_service_client]
  source           = "./../../../modules/ecs/autoscaling"
  name             = "${var.environment_name}-client"
  cluster_name     = var.ecs_cluster_name
  min_capacity     = var.ecs_autoscaling_min_capacity["client"]
  max_capacity     = var.ecs_autoscaling_max_capacity["client"]
  cpu_threshold    = var.cpu_threshold["client"]
  memory_threshold = var.memory_threshold["client"]
}

# ------- CodePipeline -------

# ------- Creating Bucket to store CodePipeline artifacts -------
module "s3_codepipeline" {
  source      = "./../../../modules/s3"
  bucket_name = "codepipeline-${var.aws_region}-${random_id.RANDOM_ID.hex}"
}

# ------- Creating IAM roles used during the pipeline excecution -------
module "devops_role" {
  source             = "./../../../modules/iam"
  create_devops_role = true
  name               = var.iam_role_name["devops"]
}

module "codedeploy_role" {
  source                 = "./../../../modules/iam"
  create_codedeploy_role = true
  name                   = var.iam_role_name["codedeploy"]
}

# ------- Creating an IAM Policy for role -------
module "policy_devops_role" {
  source                = "./../../../modules/iam"
  name                  = "devops-${var.environment_name}"
  create_policy         = true
  attach_to             = module.devops_role.name_role
  create_devops_policy  = true
  ecr_repositories      = [module.ecr_server.ecr_repository_arn, module.ecr_client.ecr_repository_arn]
  code_build_projects   = [module.codebuild_client.project_arn, module.codebuild_server.project_arn]
  code_deploy_resources = [module.codedeploy_server.application_arn, module.codedeploy_server.deployment_group_arn, module.codedeploy_client.application_arn, module.codedeploy_client.deployment_group_arn]
}

# ------- Creating a SNS topic -------
module "sns" {
  source   = "./../../../modules/sns"
  sns_name = "sns-${var.environment_name}"
}

# ------- Creating the server CodeBuild project -------
module "codebuild_server" {
  source                 = "./codebuild"
  name                   = "codebuild-${var.environment_name}-server"
  iam_role               = module.devops_role.arn_role
  region                 = var.aws_region
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
  source                 = "./codebuild"
  name                   = "codebuild-${var.environment_name}-client"
  iam_role               = module.devops_role.arn_role
  region                 = var.aws_region
  account_id             = data.aws_caller_identity.id_current_account.account_id
  ecr_repo_url           = module.ecr_client.ecr_repository_url
  folder_path            = var.folder_path_client
  buildspec_path         = var.buildspec_path
  task_definition_family = module.ecs_taks_definition_client.task_definition_family
  container_name         = var.container_name["client"]
  service_port           = var.port_app_client
  ecs_role               = var.iam_role_name["ecs"]
  ecs_task_role          = var.iam_role_name["ecs_task_role"]
  server_alb_url         = module.alb_server.dns_alb
}

# ------- Creating the server CodeDeploy project -------
module "codedeploy_server" {
  source          = "./codedeploy"
  name            = "Deploy-${var.environment_name}-server"
  ecs_cluster     = var.ecs_cluster_name
  ecs_service     = var.ecs_service_name["server"]
  alb_listener    = module.alb_server.arn_listener
  tg_blue         = module.target_group_server_blue.tg_name
  tg_green        = module.target_group_server_green.tg_name
  sns_topic_arn   = module.sns.sns_arn
  codedeploy_role = module.codedeploy_role.arn_role_codedeploy
  depends_on      = [module.ecs_service_server]
}

# ------- Creating the client CodeDeploy project -------
module "codedeploy_client" {
  source          = "./codedeploy"
  name            = "Deploy-${var.environment_name}-client"
  ecs_cluster     = var.ecs_cluster_name
  ecs_service     = var.ecs_service_name["client"]
  alb_listener    = module.alb_client.arn_listener
  tg_blue         = module.target_group_client_blue.tg_name
  tg_green        = module.target_group_client_green.tg_name
  sns_topic_arn   = module.sns.sns_arn
  codedeploy_role = module.codedeploy_role.arn_role_codedeploy
  depends_on      = [module.ecs_service_client]
}

# ------- Creating CodePipeline -------
module "codepipeline" {
  source                   = "./codepipeline"
  name                     = "pipeline-${var.environment_name}"
  pipe_role                = module.devops_role.arn_role
  s3_bucket                = module.s3_codepipeline.s3_bucket_id
  github_token             = var.github_token
  repo_owner               = var.repository_owner
  repo_name                = var.repository_name
  branch                   = var.repository_branch
  codebuild_project_server = module.codebuild_server.project_id
  codebuild_project_client = module.codebuild_client.project_id
  app_name_server          = module.codedeploy_server.application_name
  app_name_client          = module.codedeploy_client.application_name
  deployment_group_server  = module.codedeploy_server.deployment_group_name
  deployment_group_client  = module.codedeploy_client.deployment_group_name
  sns_topic                = module.sns.sns_arn
  depends_on               = [module.policy_devops_role]
}

# ------- Creating Bucket to store assets accessed by the Back-end -------
module "s3_assets" {
  source      = "./../../../modules/s3"
  bucket_name = "assets-${var.aws_region}-${random_id.RANDOM_ID.hex}"
}

# ------- Creating Dynamodb table by the Back-end -------
module "dynamodb_table" {
  source = "./../../../modules/dynamodb"
  name   = "assets-table-${var.environment_name}"
}
