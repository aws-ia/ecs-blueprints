variable "name" {
  type = string
  description = "Name of the Launch Template"
}
variable "volume_size" {
  type = string
  default = 30
}

variable "instance_initiated_shutdown_behavior" {
  type = string
  description = "Shutdown behavioure on instance"
  default = "terminate"
}

variable "instance_type" {
  type = string
  description = "ECS Container Instance Instance Type"
  default = "c5.large"
}

variable "vpc_security_group_ids" {
  type = string
  description = "Security Group Associated with ECS Container Instance"
}

variable "iam_instance_profile" {
  type = string
  description = "ECS Instance Profile"
  default = "ecsInstanceRole"
}