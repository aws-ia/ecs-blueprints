variable "aws_region" {
  description = "AWS Region in which to deploy the example."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources. Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "nodejs-multi-arch"
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret storing the Github token for authentication"
  type        = string
  default     = "ecs-github-token"
}
