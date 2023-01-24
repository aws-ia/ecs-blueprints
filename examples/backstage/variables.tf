variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "Name of secret manager secret storing github token for auth"
  type        = string
}

variable "postgresdb_master_password" {
  description = "AWS secrets manager secret name that stores the db master password"
  type        = string
  sensitive   = true
}
