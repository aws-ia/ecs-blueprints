output "github_oidc_iam_role_arn" {
  description = "The ARN of the GitHub OIDC IAM role"
  value       = module.iam_github_oidc_role.arn
}
