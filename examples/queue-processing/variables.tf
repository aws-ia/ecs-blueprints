variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
  default     = "ecs-blueprint-infra"
}

variable "service_name" {
  description = "The service name"
  type        = string
  default     = "ecs-queue-proc"
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
  default     = "./examples/queue-processing/application-code/container-queue-proc/buildspec.yml"
}

variable "folder_path" {
  description = "The location of the application code and Dockerfile files"
  type        = string
  default     = "./examples/queue-processing/application-code/container-queue-proc/."
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "terraform-aws-ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "queue-example"
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "ecs-github-token"
}

################################################################################
# Task definition parameters
################################################################################
variable "task_cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "task_memory" {
  description = "The task memory size"
  type        = string
}

variable "log_retention_in_days" {
  description = "The number of days for which to retain task logs"
  type        = number
  default     = 7
}

################################################################################
# Container definition used in task
################################################################################

variable "container_name" {
  description = "The container name to use in service task definition"
  type        = string
  default     = "ecs-queue-proc"
}

variable "container_port" {
  description = "The container port to serve traffic"
  type        = number
  default     = 3000
}

# Provide a list of map objects
# Each map object has container definition parameters
# The required parameters are container_name, container_image, port_mappings
# [
#  {
#    "container_name":"monitoring-agent",
#    "container_image": "img-repo-url"},
#    "port_mappings" : [{ containerPort = 9090, hostPort =9090, protocol = tcp}]
#  }
# ]
# see modules/ecs-container-definition for full set of parameters
# map_environment and map_secrets are common to add in container definition
# variable "sidecar_container_definitions" {
#   description = "List of container definitions to add to the task"
#   type        = list(any)
#   default     = []
# }

################################################################################
# Capacity provider strategy setting
# to distribute tasks between Fargate
# Fargate Spot
################################################################################
