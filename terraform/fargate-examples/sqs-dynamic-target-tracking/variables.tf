variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
}

variable "container_name" {
  description = "container_name"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "app_metric_name" {
  description = "app_metric_name"
  type        = string
}

variable "bpi_metric_name" {
  description = "bpi_metric_name"
  type        = string
}


variable "metric_type" {
  description = "metric_type"
  type        = string
}

variable "metric_namespace" {
  description = "metric_namespace"
  type        = string
}

variable "scaling_policy_name" {
  description = "scaling_policy_name"
  type        = string
}

variable "desired_latency" {
  description = "desired_latency"
  type        = number
}

variable "default_msg_proc_duration" {
  description = "default_msg_proc_duration"
  type        = number
}

variable "number_of_messages" {
  description = "number_of_messages"
  type        = number
}
