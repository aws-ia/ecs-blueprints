variable "aws_region" {
  description = "AWS region to deploy the blueprint resources into"
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources. Note: the scheduler Lambda reads fixed SSM parameter names (PIPELINE_*), so only one copy of this pattern can run per account and Region."
  type        = string
  default     = "ecsdemo-queue-proc"
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
