output "pipeline_role_arn" {
  description = "The ARN of the IAM role"
  value       = try(aws_iam_role.pipeline[0].arn, null)
}

output "pipeline_role_name" {
  description = "The name of the IAM role"
  value       = try(aws_iam_role.pipeline[0].name, null)
}
