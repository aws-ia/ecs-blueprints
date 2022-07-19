output "project_id" {
  description = "The ID of the CodeBuild project"
  value       = aws_codebuild_project.this.id
}

output "project_arn" {
  description = "The ARN of the CodeBuild project"
  value       = aws_codebuild_project.this.arn
}
