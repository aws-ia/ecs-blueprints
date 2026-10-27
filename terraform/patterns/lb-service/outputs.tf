output "application_url" {
  value       = "http://${module.alb.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}

output "cluster_name" {
  value       = module.ecs_cluster.name
  description = "ECS cluster created by this example"
}

output "backend_service_discovery_name" {
  value       = "backend.${local.namespace}"
  description = "Private companion backend endpoint used by the frontend"
}
