# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name for the ecs service"
  type        = string
}

variable "desired_tasks" {
  description = "The minumum number of tasks to run in the service"
  type        = string
}

variable "arn_security_group" {
  description = "ARN of the security group for the tasks"
  type        = string
}

variable "ecs_cluster_id" {
  description = "The ECS cluster ID in which the resources will be created"
  type        = string
}

variable "arn_target_group" {
  description = "The ARN of the AWS Target Group to put the ECS task"
  type        = string
}

variable "arn_task_definition" {
  description = "The ARN of the Task Definition to use to deploy the tasks"
  type        = string
}

variable "subnets_id" {
  description = "Subnet ID in which ecs will deploy the tasks"
  type        = list(string)
}

variable "container_port" {
  description = "The port that the container will listen request"
  type        = string
}

variable "container_name" {
  description = "The name of the container"
  type        = string
}

variable "seconds_health_check_grace_period" {
  description = "Number of seconds for the task health check"
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of healthy tasks during deployment"
  type        = string
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of task able to be deployed"
  type        = string
}

variable "deployment_controller" {
  description = "Deployment controller to be used"
  type        = string
}
