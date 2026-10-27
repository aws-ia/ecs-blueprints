output "application_url" {
  value       = "http://${module.service_alb.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}
