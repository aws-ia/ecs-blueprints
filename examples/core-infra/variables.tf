variable "core_stack_name" {
  description = "The name of Core Infrastructure stack, feel free to rename it"
  type        = string
  default     = "ecs-blueprint-infra"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "namespaces" {
  description = "List of service discovery namespaces for ECS services. Creates a default namespace"
  type        = list(string)
  default     = ["default", "myapp"]
}
