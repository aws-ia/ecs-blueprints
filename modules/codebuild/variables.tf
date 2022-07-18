variable "name" {
  description = "CodeBuild Project name"
  type        = string
}

variable "description" {
  description = "Short description of the project"
  type        = string
  default     = null
}

variable "build_timeout" {
  description = "Number of minutes, from 5 to 480 (8 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed. The default is 10 minutes"
  type        = number
  default     = 10
}

variable "service_role" {
  description = "Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account"
  type        = string
}

variable "environment" {
  description = "CodeBuild environment configuration details. At least one attribute is required since `environment` is a required by CodeBuild"
  type        = any
  default = {
    image = "aws/codebuild/standard:4.0"
  }
}

variable "logs_config" {
  description = "CodeBuild logs configuration details"
  type        = any
  default     = {}
}

variable "buildspec_path" {
  description = "Path to for the Buildspec file"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
