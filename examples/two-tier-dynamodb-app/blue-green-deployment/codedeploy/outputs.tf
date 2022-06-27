output "deployment_group_name" {
  description = "The deployment group name for CodeDeploy"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "deployment_group_arn" {
  description = "The deployment group ARN for CodeDeploy"
  value       = aws_codedeploy_deployment_group.main.arn
}

output "application_name" {
  description = "The application name for CodeDeploy"
  value       = aws_codedeploy_deployment_group.main.app_name
}

output "application_arn" {
  description = "The application ARN for CodeDeploy"
  value       = aws_codedeploy_app.main.arn
}
