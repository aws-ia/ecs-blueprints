variable "aws_region" {
  description = "AWS Region in which to deploy the pattern."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources. Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecs-managed-instances"
}

variable "capacity_option_type" {
  description = "Managed Instances purchasing option."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_option_type)
    error_message = "capacity_option_type must be ON_DEMAND or SPOT."
  }
}

variable "scale_in_after_seconds" {
  description = "Seconds an idle Managed Instance remains before it is eligible for scale in."
  type        = number
  default     = 300

  validation {
    condition = (
      floor(var.scale_in_after_seconds) == var.scale_in_after_seconds
      && var.scale_in_after_seconds >= 0 && var.scale_in_after_seconds <= 3600
    )
    error_message = "scale_in_after_seconds must be a whole number between 0 and 3600."
  }
}

variable "require_instance_store" {
  description = "Require instance types with local SSD instance store."
  type        = bool
  default     = false
}
