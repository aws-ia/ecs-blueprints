# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name for the ecs service"
  type        = string
}

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
    container_name   = string
    container_port   = number
    target_group_arn = string
  }))
  default = []
}

variable "platform_version" {
  description = "Platform version on which to run your service"
  type        = string
  default     = "LATEST"
}

variable "task_definition" {
  description = "The ARN of the Task Definition to use to deploy the tasks"
  type        = string
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
  default     = 0
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

variable "tags" {
  description = "tags"
  type        = map(string)
}
