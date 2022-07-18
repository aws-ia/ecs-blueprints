output "arn" {
  description = "The ECS Service ARN"
  value       = aws_ecs_service.this.id
}

output "id" {
  description = "The ECS Service ID"
  value       = aws_ecs_service.this.id
}

output "name" {
  description = "The ECS Service Name"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "The family name of the task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_role_arn" {
  description = "The ARN of the task role"
  value       = aws_iam_role.task.arn
}

output "container_name" {
  description = "The name of the container"
  value       = var.container_name # passthrough
}
