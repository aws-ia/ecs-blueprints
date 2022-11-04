variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
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

variable "public_subnets_tag_value" {
  # if left blank then {core_stack_name}-public- will be used
  description = "The value tag of the public subnets"
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
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "Name of secret manager secret storing github token for auth"
  type        = string
}

# application related input parameters
variable "service_name" {
  description = "The service name"
  type        = string
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

# listener settings for the load balanced service
variable "listener_port" {
  description = "The listener port"
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "The listener protocol"
  type        = string
  default     = "HTTP"
}

# target health check
variable "health_check_path" {
  description = "The health check path"
  type        = string
  default     = "/"
}

# variable "health_check_protocol" {
#   description = "The health check protocol"
#   type        = string
#   default     = "http"
# }

variable "health_check_matcher" {
  description = "The health check passing codes"
  type        = string
  default     = "200-299"
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
  description = "The container name to use in service task definition"
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
}

variable "container_protocol" {
  description = "The container traffic protocol"
  type        = string
  default     = "HTTP"
}

# Capacity provider strategy setting
# to distribute tasks between Fargate
# Fargate Spot

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

# schedule scaling
variable "enable_scheduled_autoscaling" {
  description = "Determines whether scheduled autoscaling is enabled for the service"
  type        = bool
  default     = false
}

variable "scheduled_autoscaling_timezone" {
  description = "Timezone which scheduled scaling occurs"
  type        = string
  default     = "America/Los_Angeles"
}

variable "scheduled_autoscaling_up_time" {
  description = "Timezone which scheduled scaling occurs"
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "scheduled_autoscaling_down_time" {
  description = "Timezone which scheduled scaling occurs"
  type        = string
  default     = "cron(0 20 * * ? *)"
}

variable "scheduled_autoscaling_up_min_capacity" {
  description = "The minimum number of tasks to provision"
  type        = number
  default     = 4
}

variable "scheduled_autoscaling_up_max_capacity" {
  description = "The maximum number of tasks to provision"
  type        = number
  default     = 6
}

variable "scheduled_autoscaling_down_min_capacity" {
  description = "The minimum number of tasks to provision"
  type        = number
  default     = 1
}

variable "scheduled_autoscaling_down_max_capacity" {
  description = "The maximum number of tasks to provision"
  type        = number
  default     = 3
}

variable "postgresdb_master_username" {
  type        = string
  description = "The master username for backstage postgress db"
  default     = "postgres"
}

variable "postgresdb_master_password" {
  type        = string
  description = "AWS secrets manager secret name that stores the db master password"
}

variable "postgresdb_name" {
  type        = string
  description = "Name of the backstage postgres db"
  default     = "backstage-db"
}

variable "postgresdb_port" {
  type        = string
  description = "Postgres db port"
  default     = "5432"
}
