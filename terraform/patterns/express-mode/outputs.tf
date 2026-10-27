output "quick_start_url" {
  description = "Provider-reported HTTPS endpoint for the image-based Express Mode service."
  value       = try(module.quick_start.ingress_paths[0].endpoint, null)
}

output "quick_start_ingress_paths" {
  description = "Express Mode endpoints and their PUBLIC or PRIVATE access types."
  value       = module.quick_start.ingress_paths
}

output "custom_task_definition_url" {
  description = "HTTPS endpoint for the custom-task-definition Express Mode service."
  value       = try(aws_cloudformation_stack.custom[0].outputs["Endpoint"], null)
}

output "custom_task_definition_service_arn" {
  description = "ARN of the custom-task-definition Express Mode service."
  value       = try(aws_cloudformation_stack.custom[0].outputs["ServiceArn"], null)
}

output "resource_name_prefix" {
  description = "Generated name prefix used to audit service-managed resources after cleanup."
  value       = local.name
}
