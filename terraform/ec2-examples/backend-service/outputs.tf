output "service_discovery_arn" {
  description = "Service discovery arn"
  value       = aws_service_discovery_service.this.arn
}

output "service_discovery_name" {
  description = "Service name"
  value       = aws_service_discovery_service.this.name
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = aws_service_discovery_service.this.namespace_id
}
