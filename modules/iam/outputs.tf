output "devops_role_arn" {
  description = "The ARN of the IAM role"
  value       = try(aws_iam_role.devops[0].arn, null)
}

output "devops_role_name" {
  description = "The name of the IAM role"
  value       = try(aws_iam_role.devops[0].name, null)
}

output "codedeploy_role_arn" {
  description = "The ARN of the CodeDeploy IAM role"
  value       = try(aws_iam_role.codedeploy[0].arn, null)
}

output "codedeploy_role_name" {
  description = "The name of the IAM role"
  value       = try(aws_iam_role.codedeploy[0].name, null)
}
