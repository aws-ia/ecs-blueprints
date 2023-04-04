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

### IAM

variable "iam_role_name" {
  description = "The name for the Role"
  type        = string
}

variable "iam_role_use_name_prefix" {
  description = "Determines whether the IAM role name (`iam_role_name`) is used as a prefix"
  type        = bool
  default     = true
}

variable "create_iam_role" {
  description = "Set this variable to true if you want to create a role for AWS DevOps Tools"
  type        = bool
  default     = false
}

variable "ecr_repository" {
  description = "The ECR repositories to which grant IAM access"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket used for the artifact store"
  type = object({
    s3_bucket_id  = string
    s3_bucket_arn = string
  })
}
