variable "aws_region" {
  description = "AWS Region in which to deploy the pattern."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources (maximum 18 characters). Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecs-svc-connect"

  validation {
    condition     = length(var.name) <= 18
    error_message = "The name must be 18 characters or fewer so generated IAM role name prefixes remain within AWS limits."
  }
}

variable "private_ca_arn" {
  description = "Optional ACM Private CA ARN used to enable Service Connect TLS. Private CA charges apply."
  type        = string
  default     = null
}

variable "service_connect_namespace_arn" {
  description = "Optional existing Cloud Map HTTP namespace ARN, including a RAM-shared cross-account namespace."
  type        = string
  default     = null
}
