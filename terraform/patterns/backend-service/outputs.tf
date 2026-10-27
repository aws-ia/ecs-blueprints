
output "service_discovery_arn" {
  value       = aws_service_discovery_service.this.arn
  description = "Service discovery arn"
}

output "service_discovery_name" {
  value       = aws_service_discovery_service.this.name
  description = "Service name"
}

output "service_discovery_namespace" {
  value       = aws_service_discovery_private_dns_namespace.this.name
  description = "Private DNS namespace"
}

output "service_discovery_endpoint" {
  value       = "http://backend.${local.namespace}:${local.server_port}"
  description = "Private backend endpoint reachable from this VPC"
}

output "cluster_name" {
  value       = module.ecs_cluster.name
  description = "ECS cluster created by this example"
}
