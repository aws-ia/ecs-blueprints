
output "service_discovery_url" {
  value       = aws_service_discovery_service.sd_service.arn
  description = "Copy this value in your browser in order to access the deployed app"
}
output "service_discovery_name" {
  value       = aws_service_discovery_service.sd_service.name
  description = "Copy this value in your browser in order to access the deployed app"
}

