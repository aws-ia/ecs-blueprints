variable "aws_region" {
  description = "AWS Region in which to deploy the pattern."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources. Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecs-ipv6-only"
}

variable "manage_account_setting" {
  description = "Whether this root manages the Region-wide ECS dualStackIPv6 account default. Leave false and enable it once as a prerequisite (see README); set true only in a dedicated account, where `terraform destroy` will also disable it."
  type        = bool
  default     = false
}
