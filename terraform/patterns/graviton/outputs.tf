output "application_url_amd64" {
  value       = "http://${module.alb_amd64.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app (x86 service)"
}

output "application_url_arm64" {
  value       = "http://${module.alb_arm64.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app (Graviton/arm64 service)"
}

output "cluster_name" {
  value       = module.ecs_cluster.name
  description = "ECS cluster created by this example"
}
