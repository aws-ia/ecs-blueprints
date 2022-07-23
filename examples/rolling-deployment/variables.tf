variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
}

variable "vpc_tag_key" {
  description = "The tag key of the VPC and subnets"
  type        = string
  default     = "Name"
}

variable "vpc_tag_value" {
  # if left blank then {core_stack_name} will be used
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = ""
}

variable "public_subnets" {
  # if left blank then {core_stack_name}-public- will be used
  description = "The value tag of the public subnets"
  type        = string
  default     = ""
}

variable "private_subnets" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  # if left blank then {core_stack_name} will be used
  description = "The ID of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_name" {
  # if left blank then {core_stack_name}-execution will be used
  description = "The ARN of the task execution role"
  type        = string
  default     = ""
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
