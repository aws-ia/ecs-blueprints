variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
  default     = "ecs-blueprint-infra"
}

variable "vpc_tag_key" {
  description = "The tag key of the VPC and subnets"
  type        = string
  default     = "Name"
}

variable "vpc_tag_value" {
  # if left blank then {core_stack_name} will be used
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = ""
}

variable "private_subnets_tag_value" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  # if left blank then {core_stack_name} will be used
  description = "The ID of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_name" {
  # if left blank then {core_stack_name}-execution will be used
  description = "The ARN of the task execution role"
  type        = string
  default     = ""
}

# Application variables
variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./application-code/ecsdemo-nodejs/templates/buildspec.yml"
}

variable "folder_path" {
  description = "The location of the application code and Dockerfile files"
  type        = string
  default     = "./application-code/ecsdemo-nodejs/."
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "ecs-github-token"
}

################################################################################
# Servie definition parameters
################################################################################

# application related input parameters
variable "service_name" {
  description = "The service name"
  type        = string
  default     = "ecsdemo-backend"
}

variable "namespace" {
  description = "The service discovery namespace"
  type        = string
  default     = "default"
}

variable "desired_count" {
  description = "The number of task replicas for service"
  type        = number
  default     = 1
}

################################################################################
# Task definition parameters
################################################################################
variable "cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "memory" {
  description = "The task memory size"
  type        = number
}

variable "container_name" {
  description = "The name of the main container"
  type        = string
}

################################################################################
# Container definition used in task
################################################################################

variable "container_definition_defaults" {
  description = "Default values to use on all container definitions created if a specific value is not specified"
  type        = any
  default     = {}
}

variable "container_port" {
  description = "The container port to serve traffic"
  type        = number
  default     = 3000
}

################################################################################
# Capacity provider strategy setting
# to distribute tasks between Fargate
# Fargate Spot
################################################################################

variable "cp_strategy_base" {
  description = "Base number of tasks to create on Fargate on-demand"
  type        = number
  default     = 1
}

variable "cp_strategy_fg_weight" {
  description = "Relative number of tasks to put in Fargate"
  type        = number
  default     = 1
}

variable "cp_strategy_fg_spot_weight" {
  description = "Relative number of tasks to put in Fargate Spot"
  type        = number
  default     = 0
}
