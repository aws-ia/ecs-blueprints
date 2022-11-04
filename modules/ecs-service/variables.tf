variable "name" {
  description = "The name for the ecs service"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

################################################################################
# Service
################################################################################

variable "desired_count" {
  description = "The desired number of instantiations of the task definition to keep running on the service."
  type        = number
  default     = 1
}

variable "security_groups" {
  description = "Security groups associated with the task or service. If you do not specify a security group, the default security group for the VPC is used."
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "The ECS cluster ID in which the resources will be created"
  type        = string
}

variable "load_balancers" {
  description = "A list of load balancer config objects for the ECS service"
  type = list(object({
    target_group_arn = string
  }))
  default = []
}

variable "service_registry_list" {
  description = "A list of service discovery registry names for the service"
  type = list(object({
    registry_arn = string
  }))
  default = []
}

variable "platform_version" {
  description = "Platform version on which to run your service"
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnets associated with the task or service."
  type        = list(string)
}

variable "enable_ecs_managed_tags" {
  description = "Specifies whether to enable Amazon ECS managed tags for the tasks within the service."
  type        = bool
  default     = true
}

variable "propagate_tags" {
  description = "Specifies whether to propagate the tags from the task definition or the service to the tasks. The valid values are SERVICE and TASK_DEFINITION."
  type        = string
  default     = "SERVICE"
}

variable "enable_execute_command" {
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service."
  type        = bool
  default     = false
}

variable "health_check_grace_period_seconds" {
  description = "Number of seconds for the task health check"
  type        = number
  default     = 30
}

variable "deployment_minimum_healthy_percent" {
  description = "The minimum number of tasks, specified as a percentage of the Amazon ECS service's DesiredCount value, that must continue to run and remain healthy during a deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of task able to be deployed"
  type        = number
  default     = 200
}

variable "deployment_controller" {
  description = "Specifies which deployment controller to use for the service."
  type        = string
  default     = "ECS"
}

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

################################################################################
# Task Definition
################################################################################

variable "lb_container_name" {
  description = "The container name for the LB"
  type        = string
  default     = null
}

variable "cpu" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 256
}

variable "memory" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 1024
}

variable "lb_container_port" {
  description = "The port that the container will use to listen to requests"
  type        = number
  default     = null
}

variable "attach_task_role_policy" {
  description = "Attach the task role policy to the task role"
  type        = bool
  default     = true
}

variable "task_role_policy" {
  description = "The task's role policy"
  type        = string
  default     = null
}

variable "execution_role_arn" {
  description = "ecs-blueprint-infra ECS execution ARN"
  type        = string
}

variable "operating_system_family" {
  description = "The OS family for task"
  type        = string
  default     = "LINUX"
}

variable "task_cpu_architecture" {
  description = "CPU architecture X86_64 or ARM64"
  type        = string
  default     = "X86_64"
}

################################################################################
# Container Definition
################################################################################

variable "container_definitions" {
  description = "Map of maps that define container definitions to create"
  type        = any
  default     = {}
}

variable "container_definition_defaults" {
  description = "Default values to use on all container definitions created if a specific value is not specified"
  type        = any
  default     = {}
}

################################################################################
# Autoscaling
################################################################################

#Target Scaling
variable "enable_autoscaling" {
  description = "Determines whether autoscaling is enabled for the service"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "The minimum number of tasks to provision"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "The maximum number of tasks to provision"
  type        = number
  default     = 3
}

variable "autoscaling_memory_threshold" {
  description = "The desired threashold for memory consumption"
  type        = number
  default     = 75
}

variable "autoscaling_cpu_threshold" {
  description = "The desired threashold for CPU consumption"
  type        = number
  default     = 75
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

#cron syntax (s m h day-of-month month day-of-week year)
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
