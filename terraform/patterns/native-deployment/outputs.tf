output "application_url" {
  description = "Production endpoint."
  value       = "http://${module.alb.dns_name}"
}

output "test_url" {
  description = "Restricted test endpoint used by traffic-shifting deployments."
  value       = "http://${module.alb.dns_name}:8080"
}

output "cluster_name" {
  description = "ECS cluster name used by the operational commands in the README."
  value       = module.ecs_cluster.name
}

output "service_name" {
  description = "ECS service name used by the operational commands in the README."
  value       = module.ecs_service.name
}
