variable "region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region you want to deploy to."
}

variable "target_task_execution_role_arn" {
  description = "Execution role ARN used by the target ECS task definition."
  type        = string
}

variable "target_task_role_arn" {
  description = "Task role ARN used by the target ECS task definition."
  type        = string
}
