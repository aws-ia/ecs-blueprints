variable "core_stack_name" {
  description = "The name of Core Infrastructure stack, feel free to rename it. Used for cluster and VPC names."
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

variable "enable_nat_gw" {
  description = "Provision a NAT Gateway in the VPC"
  type        = bool
  default     = true

}

variable "instance_type" {
  type        = string
  description = "ECS Container Instance Instance Type"
  default     = "c6a.2xlarge"
}

variable "asg_name" {
  type        = string
  description = "Name of the AutoScaling Group"
  default     = "ecs_blueprint_asg"
}

variable "desired_capacity" {
  type        = number
  description = "Desire Capacity Of AutoScalingGroup"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum Size Of AutoScalingGroup"
  default     = 4
}

variable "min_size" {
  type        = number
  description = "Minimum Size Of AutoScalingGroup"
  default     = 1
}

variable "launch_name" {
  type        = string
  description = "Name of the Launch Template"
  default     = "ecs-blueprint-launch_template"
}
variable "volume_size" {
  type    = string
  default = 30
}

variable "instance_initiated_shutdown_behavior" {
  type        = string
  description = "Shutdown behavioure on instance"
  default     = "terminate"
}

variable "volume_type" {
  type        = string
  description = "Volume type to be used"
  default     = "gp2"
}

variable "capcitiy-provider_name" {
  type        = string
  description = "Name of capacity provider"
  default     = "capacity-provide-blue-print"
}
