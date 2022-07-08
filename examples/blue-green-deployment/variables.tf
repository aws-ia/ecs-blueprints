
variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./templates/buildspec_bluegreen.yml"
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
  default     = "main"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "refactor/module-resource-consolidation"
}
