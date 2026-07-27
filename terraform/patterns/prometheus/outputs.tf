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

output "amp_workspace_id" {
  value       = aws_prometheus_workspace.this.id
  description = "Amazon Managed Service for Prometheus workspace ID"
}

output "amp_remote_write_endpoint" {
  value       = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
  description = "Remote write endpoint of the AMP workspace the collector sends metrics to"
}
