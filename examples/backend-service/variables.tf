variable "region" {
  description = "aws region"
  type        = string
}

variable "namespace" {
  description = "A namespace for the app.  This gets applied to things like the ECS Cluster and Service name"
  type        = string
}

variable "image" {
  description = "the container image"
  type        = string
}

variable "cpu" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 256
}

variable "memory" {
  description = "The amount (in MiB) of memory used by the task."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "The desired number of instantiations of the task definition to keep running on the service."
  type        = number
  default     = 1
}

variable "logs_retention_in_days" {
  description = "how many days are retained for"
  type        = number
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
}
