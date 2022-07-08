variable "name" {
  description = "The name for the Role"
  type        = string
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

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}
