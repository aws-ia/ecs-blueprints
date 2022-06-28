variable "name" {
  description = "The CodePipeline pipeline name"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "pipe_role" {
  description = "The role assumed by CodePipeline"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket used for the artifact store"
  type        = string
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

variable "codebuild_project_server" {
  description = "Server's CodeBuild project name"
  type        = string
}

variable "codebuild_project_client" {
  description = "Client's CodeBuild project name"
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

variable "client_deploy_configuration" {
  description = "The configuration to use for the client deployment"
  type        = map(string)
  default     = {}
}

variable "server_deploy_configuration" {
  description = "The configuration to use for the server deployment"
  type        = map(string)
  default     = {}
}
