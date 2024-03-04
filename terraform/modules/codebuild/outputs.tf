output "project_id" {
  description = "The ID of the CodeBuild project"
  value       = aws_codebuild_project.this.id
}

output "project_arn" {
  description = "The ARN of the CodeBuild project"
  value       = aws_codebuild_project.this.arn
}

output "codebuild_role_arn" {
  description = "The ARN of the IAM role"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "codebuild_role_name" {
  description = "The name of the IAM role"
  value       = try(aws_iam_role.this[0].name, null)
}
