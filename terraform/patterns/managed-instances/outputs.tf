output "application_url" {
  description = "Managed Instances service endpoint."
  value       = "http://${module.alb.dns_name}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "capacity_provider_name" {
  description = "Managed Instances capacity provider name."
  value       = aws_ecs_capacity_provider.this.name
}

output "managed_daemon_arn" {
  description = "Managed Daemon ARN."
  value       = aws_ecs_daemon.telemetry.arn
}
