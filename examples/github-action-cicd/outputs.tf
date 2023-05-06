output "task_definition_family" {
  description = "The ECS Task Definition family"
  value       = module.ecs_service.task_definition_family
}

output "ecs_service_name" {
  description = "The name of the ECS Service"
  value       = module.ecs_service.name
}
