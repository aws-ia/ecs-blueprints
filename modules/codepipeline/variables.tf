variable "name" {
  description = "The CodePipeline pipeline name"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "s3_bucket" {
  description = "S3 bucket used for the artifact store"
  type = object({
    s3_bucket_id  = string
    s3_bucket_arn = string
  })
}

variable "github_token" {
  description = "Personal access token from Github"
  type        = string
  sensitive   = true
}

variable "repo_owner" {
  description = "The username of the Github repository owner"
  type        = string
}

variable "repo_name" {
  description = "Github repository's name"
  type        = string
}

variable "branch" {
  description = "Github branch used to trigger the CodePipeline"
  type        = string
}

variable "codebuild_project_app" {
  description = "Server's CodeBuild project name"
  type        = string
}

variable "sns_topic" {
  description = "The ARN of the SNS topic to use for pipline notifications"
  type        = string
}

variable "deploy_provider" {
  description = "The provider to use for deployment"
  type        = string
  default     = "ECS"
}

variable "app_deploy_configuration" {
  description = "The configuration to use for the client deployment"
  type        = map(string)
  default     = {}
}

variable "iam_role_name" {
  description = "The name for the Role"
  type        = string
}

variable "create_iam_role" {
  description = "Set this variable to true if you want to create a role for AWS DevOps Tools"
  type        = bool
  default     = false
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

variable "service_role" {
  description = "Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account"
  type        = string
}
