output "project_id" {
  description = "CodeBuild project ID."
  value       = aws_codebuild_project.this.id
}

output "project_arn" {
  description = "CodeBuild project ARN."
  value       = aws_codebuild_project.this.arn
}
