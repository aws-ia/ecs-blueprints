# Shared resources from core-infra variables
variable "vpc_tag_key" {
  description = "The tag key of the VCP and subnets"
  type        = string
  default     = "Name" 
}

variable "vpc_tag_value" {
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = "core-infra"
}

variable "public_subnets" {
  description = "The value tag of the public subnets"
  type        = string
  default     = "core-infra-public-"
}
variable "private_subnets" {
  description = "The value tag of the private subnets"
  type        = string
  default     = "core-infra-private-"
}

variable "ecs_cluster_name" {
  description = "The ID of the ECS cluster"
  type        = string
  default     = "core-infra"
}

variable "ecs_task_execution_role_name" {
  description = "The ARN of the task execution role"
  type        = string
  default     = "core-infra-execution"
}

# Application variables
variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./templates/buildspec_rolling.yml"
}

variable "folder_path_server" {
  description = "The location of the server files"
  type        = string
  default     = "./application-code/server/."
}

variable "folder_path_client" {
  description = "The location of the client files"
  type        = string
  default     = "./application-code/client/."
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
  default     = "aws-ia"
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "terraform-aws-ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}
