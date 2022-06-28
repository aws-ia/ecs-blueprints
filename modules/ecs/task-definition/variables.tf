variable "name" {
  description = "The name for Task Definition"
  type        = string
}

variable "container_name" {
  description = "The name of the Container specified in the Task definition"
  type        = string
  default     = "app"
}

variable "execution_role" {
  description = "The task execution role arn"
  type        = string
}

variable "task_role" {
  description = "The IAM role that the ECS task will use to call other AWS services"
  type        = string
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

variable "region" {
  description = "AWS Region in which the resources will be deployed"
  type        = string
}

variable "container_port" {
  description = "The port that the container will use to listen to requests"
  type        = number
  default     = 8080
}

variable "cloudwatch_log_group" {
  description = "cloudwatch log group"
  type        = string
}
