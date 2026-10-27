variable "iam_role_name" {
  description = "Name of the IAM role assumed by CodeBuild."
  type        = string
}

variable "buildspec_path" {
  description = "Path to the CodeBuild buildspec."
  type        = string
}

variable "name" {
  description = "Name of the CodeBuild project."
  type        = string
}

variable "artifact_bucket_arn" {
  description = "ARN of the S3 bucket containing pipeline artifacts and Terraform state."
  type        = string
}

variable "terraform_state_parameter_arn" {
  description = "ARN of the SSM parameter containing the Terraform state bucket name."
  type        = string
}

variable "pass_role_arns_by_service" {
  description = "Map of service principals to deployment role ARNs that CodeBuild may pass."
  type        = map(list(string))
  default     = {}
}

variable "deployment_policy_statements" {
  description = "Non-IAM AWS permissions required by the Terraform deployment."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for statement in var.deployment_policy_statements : [
        for action in statement.actions :
        length(regexall("^(iam|sts):", lower(action))) == 0
      ]
    ]))
    error_message = "deployment_policy_statements cannot grant IAM or STS actions; use pass_role_arns_by_service for scoped iam:PassRole access."
  }
}

variable "environment_variables" {
  description = "Plaintext environment variables supplied to the CodeBuild project."
  type        = map(string)
  default     = {}
}

variable "log_retention_in_days" {
  description = "Retention period for CodeBuild logs."
  type        = number
  default     = 7
}
