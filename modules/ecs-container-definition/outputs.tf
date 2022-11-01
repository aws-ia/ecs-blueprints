################################################################################
# Container Definition
################################################################################

output "definition" {
  description = "Container definition"
  value       = local.container_definition
}

output "encoded_definition" {
  description = "JSON encoded container definition"
  value       = local.container_definition
}

################################################################################
# CloudWatch Log Group
################################################################################

output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = try(aws_cloudwatch_log_group.this[0].name, "")
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = try(aws_cloudwatch_log_group.this[0].arn, "")
}
