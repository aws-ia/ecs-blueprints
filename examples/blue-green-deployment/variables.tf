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

variable "github_token_secret_name" {
  description = "The name of the Secret Manager secret with your GitHub token as value"
  type        = string
  default     = "ecs-github-token"
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

# application related input parameters
variable "desired_count" {
  description = "The number of task replicas for service"
  type        = number
  default     = 1
}

# listener settings for the load balanced service
variable "listener_protocol" {
  description = "The listener protocol"
  type        = string
  default     = "HTTP"
}

# target health check
variable "health_check_path" {
  description = "The health check path"
  type        = string
  default     = "/status"
}

variable "task_cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "task_memory" {
  description = "The task memory size"
  type        = string
}

variable "container_name" {
  description = "The container name to use in service task definition"
  type        = string
}

variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./application-code/client/templates/buildspec_bluegreen.yml"
}

variable "folder_path_server" {
  description = "The location of the server files"
  type        = string
  default     = "./application-code/server/."
}

variable "folder_path_client" {
  description = "The location of the client files"
  type        = string
  default     = "./application-code/client/."
}

variable "repository_owner" {
  description = "The name of the owner of the forked Github repository"
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
  default     = "main"
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
