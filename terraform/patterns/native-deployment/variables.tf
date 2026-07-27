variable "aws_region" {
  description = "AWS Region in which to deploy the pattern."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources (maximum 18 characters). Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecs-native-deploy"

  validation {
    condition     = length(var.name) <= 18
    error_message = "The name must be 18 characters or fewer so generated IAM role name prefixes remain within AWS limits."
  }
}

variable "deployment_strategy" {
  description = "ECS native deployment strategy."
  type        = string
  default     = "ROLLING"

  validation {
    condition     = contains(["ROLLING", "BLUE_GREEN", "LINEAR", "CANARY"], var.deployment_strategy)
    error_message = "deployment_strategy must be ROLLING, BLUE_GREEN, LINEAR, or CANARY."
  }
}

variable "test_listener_cidr" {
  description = "CIDR allowed to reach the test listener. Keep this restricted to a VPN, bastion, or test runner network."
  type        = string
  default     = "10.0.0.0/8"
}
