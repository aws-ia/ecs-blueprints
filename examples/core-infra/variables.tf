variable "core_stack_name" {
  description = "The name of Core Infrastructure stack, feel free to rename it. Used for cluster and VPC names."
  type        = string
  default     = "ecs-blueprint-infra"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
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

variable "enable_nat_gw" {
  description = "Provision a NAT Gateway in the VPC"
  type        = bool
  default     = true

}
