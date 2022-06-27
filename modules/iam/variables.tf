# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name for the Role"
  type        = string
}

variable "name_ecs_task_role" {
  description = "The name for the Ecs Task Role"
  type        = string
  default     = null
}

variable "create_ecs_role" {
  description = "Set this variable to true if you want to create a role for ECS"
  type        = bool
  default     = false
}

variable "create_devops_role" {
  description = "Set this variable to true if you want to create a role for AWS DevOps Tools"
  type        = bool
  default     = false
}

variable "create_codedeploy_role" {
  description = "Set this variable to true if you want to create a role for AWS CodeDeploy"
  type        = bool
  default     = false
}

variable "create_devops_policy" {
  description = "Set this variable to true if you want to create a policy for AWS DevOps Tools"
  type        = bool
  default     = false
}

variable "attach_to" {
  description = "The ARN or role name to attach the policy created"
  type        = string
  default     = ""
}

variable "ecr_repositories" {
  description = "The ECR repositories to which grant IAM access"
  type        = list(string)
  default     = ["*"]
}

variable "code_build_projects" {
  description = "The Code Build projects to which grant IAM access"
  type        = list(string)
  default     = ["*"]
}

variable "code_deploy_resources" {
  description = "The Code Deploy applications and deployment groups to which grant IAM access"
  type        = list(string)
  default     = ["*"]
}

variable "dynamodb_table" {
  description = "The name of the Dynamodb table to which grant IAM access"
  type        = list(string)
  default     = ["*"]
}

variable "s3_bucket_assets" {
  description = "The name of the S3 bucket to which grant IAM access"
  type        = list(string)
  default     = ["*"]
}
