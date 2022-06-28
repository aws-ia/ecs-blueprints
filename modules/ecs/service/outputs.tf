output "service_arn" {
  description = "The ECS Service ARN"
  value       = aws_ecs_service.main.id
}
