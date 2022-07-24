
output "service_discovery_arn" {
  value       = aws_service_discovery_service.sd_service.arn
  description = "Service discovery arn"
}
output "service_discovery_name" {
  value       = aws_service_discovery_service.sd_service.name
  description = "Service name"
}
output "service_discovery_namespace" {
  value       = aws_service_discovery_service.sd_service.namespace_id
  description = "Service discovery namespace"
}
