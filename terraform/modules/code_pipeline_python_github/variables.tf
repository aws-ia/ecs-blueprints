variable "repository_name" {
  type        = string
  description = "The repository name to use in CodePipeline source stage"
}

variable "branch_name" {
  type        = string
  description = "The repository branch name to use in CodePipeline source stage"
  default     = "main"
}

variable "artifacts_bucket_arn" {
  type        = string
  description = "The s3 artifacts bucket ARN"
}

variable "artifacts_bucket_encryption_key_arn" {
  type        = string
  description = "The s3 artifacts bucket KMS key ARN"
}

variable "account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
}

variable "build_compute_type" {
  type        = string
  description = "The CodeBuild projects compute type"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
  type        = string
  description = "The CodeBuild projects image"
  default     = "aws/codebuild/standard:7.0"
}

variable "pipeline_articats_bucket_name" {
  type        = string
  description = "The Pipeline artifacts bucket name"
}

variable "ecr_repository_name" {
  type        = string
  description = "The ECR repository name for the app"
}

variable "cluster_name" {
  type        = string
  description = "The ECS cluster name"
}

variable "container_name" {
  type        = string
  description = "The ECS service main container name"
}

variable "service_name" {
  type        = string
  description = "The ECS service name"
}

variable "code_star_connection_arn" {
  type        = string
  description = "The CodeStar connection ARN"
}

variable "organization_name" {
  type        = string
  description = "The Github organization name"
}

variable "dockerhub_secret_name" {
  type        = string
  description = "AWS Secrets Manager secret name for dockerhub credentials"
}