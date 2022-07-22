output "deployment_group_name" {
  description = "The deployment group name for CodeDeploy"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "deployment_group_arn" {
  description = "The deployment group ARN for CodeDeploy"
  value       = aws_codedeploy_deployment_group.this.arn
}

output "application_name" {
  description = "The application name for CodeDeploy"
  value       = aws_codedeploy_deployment_group.this.app_name
}

output "application_arn" {
  description = "The application ARN for CodeDeploy"
  value       = aws_codedeploy_app.this.arn
}

output "codedeploy_role_arn" {
  description = "The ARN of the IAM role"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "codedeploy_role_name" {
  description = "The name of the IAM role"
  value       = try(aws_iam_role.this[0].name, null)
}
