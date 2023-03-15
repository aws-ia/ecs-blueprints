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

variable "container_image" {
  description = "Namespace/name of the main container"
  type        = string
}

variable "container_command" {
  description = "Container command (optional)"
  type        = list(any)
  default     = []
}

################################################################################
# Sysdig specific parameters
################################################################################

variable "sysdig_access_key" {
  description = "Sysdig Agent Token"
  type        = string
}

variable "sysdig_secure_api_token" {
  description = "Sysdig API Token"
  type        = string
}

variable "sysdig_collector_url" {
  description = "Sysdig Collector Url"
  type        = string
}

variable "sysdig_collector_port" {
  description = "Sysdig Collector Port"
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

# Provide a list of map objects
# Each map object has container definition parameters
# The required parameters are container_name, container_image, port_mappings
# [
#  {
#    "container_name":"workload-agent",
#    "container_image": "img-repo-url"},
#    "port_mappings" : [{ containerPort = 9090, hostPort =9090, protocol = tcp}]
#  }
# ]
# see modules/ecs-container-definition for full set of parameters
# map_environment and map_secrets are common to add in container definition
variable "sidecar_container_definition" {
  description = "List of container definitions to add to the task"
  type        = any
  default     = {}
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
