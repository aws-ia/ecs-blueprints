variable "name" {
  description = "The name of the CodeDeploy application"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "ecs_cluster" {
  description = "The name of the ECS cluster where to deploy"
  type        = string
}

variable "ecs_service" {
  description = "The name of the ECS service to deploy"
  type        = string
}

variable "alb_listener" {
  description = "The ARN of the ALB listener for production"
  type        = string
}

variable "tg_blue" {
  description = "The Target group name for the Blue part"
  type        = string
}

variable "tg_green" {
  description = "The Target group name for the Green part"
  type        = string
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic where to deliver notifications"
  type        = string
}

variable "trigger_name" {
  description = "The name of the notification trigger"
  type        = string
  default     = "CodeDeploy_notification"
}

## IAM
variable "create_iam_role" {
  description = "Set this variable to true if you want to create a role for AWS CodeDeploy"
  type        = bool
  default     = false
}

variable "iam_role_name" {
  description = "The name for the Role"
  type        = string
}

variable "iam_role_use_name_prefix" {
  description = "Determines whether the IAM role name (`iam_role_name`) is used as a prefix"
  type        = bool
  default     = true
}

variable "service_role" {
  description = "Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account"
  type        = string
}
