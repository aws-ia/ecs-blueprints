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

variable "log_retention_in_days" {
  description = "The number of days for which to retain task logs"
  type        = number
  default     = 7
}
################################################################################
# Task Definition
################################################################################

variable "container_name" {
  description = "The name of the Container specified in the Task definition"
  type        = string
  default     = "app"
}

variable "cpu" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 256
}

variable "memory" {
  description = "The MEMORY value to assign to the container, read AWS documentation to available values"
  type        = number
  default     = 512
}

variable "image" {
  description = "The container image"
  type        = string
}

variable "container_port" {
  description = "The port that the container will use to listen to requests"
  type        = number
  default     = 8080
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
