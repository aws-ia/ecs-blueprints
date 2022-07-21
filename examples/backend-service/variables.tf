variable "ecs_task_execution_role_name" {
  description = "The ARN of the task execution role"
  type        = string
  default     = "ecs-blueprint-infra-execution"
}
