
output "service_discovery_arn" {
  value       = aws_service_discovery_service.this.arn
  description = "Service discovery arn"
}

output "service_discovery_name" {
  value       = aws_service_discovery_service.this.name
  description = "Service name"
}

output "service_discovery_namespace" {
  value       = aws_service_discovery_service.this.namespace_id
  description = "Service discovery namespace"
}
