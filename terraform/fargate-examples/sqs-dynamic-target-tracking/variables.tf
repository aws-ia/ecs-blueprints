variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
  default     = "aws-ia"
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "ecs-github-token"
}

variable "container_name" {
  description = "container_name"
  type        = string
  default     = "ecsdemo-queue-proc3"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  #default     = "us-east-1"
  default     = "us-west-2"
}

variable "app_metric_name" {
  description = "app_metric_name"
  type        = string
  default     = "MsgProcessingDuration"
}

variable "bpi_metric_name" {
  description = "bpi_metric_name"
  type        = string
  default     = "ecsTargetBPI"
}


variable "metric_type" {
  description = "metric_type"
  type        = string
  default     = "Single-Queue"
}

variable "metric_namespace" {
  description = "metric_namespace"
  type        = string
  default     = "ECS-SQS-BPI"
}

variable "scaling_policy_name" {
  description = "scaling_policy_name"
  type        = string
  default     = "ecs_sqs_scaling"
}

variable "desired_latency" {
  description = "desired_latency"
  type        = number
  default     = 60
}

variable "default_msg_proc_duration" {
  description = "default_msg_proc_duration"
  type        = number
  default     = 5
}

variable "number_of_messages" {
  description = "number_of_messages"
  type        = number
  default     = 50
}
