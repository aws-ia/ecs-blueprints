variable "core_stack_name" {
  type    = string
  default = "ecs-blueprint-infra"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}