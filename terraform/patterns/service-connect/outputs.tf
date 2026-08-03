output "frontend_url" {
  description = "Public frontend URL."
  value       = "http://${module.alb.dns_name}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_cluster.name
}

output "service_names" {
  description = "Service names keyed by frontend, API, and backend."
  value = {
    frontend = module.frontend.name
    api      = module.api.name
    backend  = module.backend.name
  }
}

output "service_connect_namespace_arn" {
  description = "Cloud Map namespace used by Service Connect."
  value       = local.namespace_arn
}
