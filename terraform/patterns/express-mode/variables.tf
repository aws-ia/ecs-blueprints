variable "aws_region" {
  description = "AWS Region in which to deploy the pattern."
  type        = string
  default     = "us-west-2"
}

variable "enable_custom_task_definition" {
  description = "Deploy the custom-task-definition Express service."
  type        = bool
  default     = false
}

variable "name" {
  description = "Name prefix for resources (maximum 18 characters). Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecs-express"

  validation {
    condition     = length(var.name) <= 18
    error_message = "The name must be 18 characters or fewer so generated IAM role name prefixes remain within AWS limits."
  }
}
