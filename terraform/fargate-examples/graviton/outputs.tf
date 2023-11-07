output "application_url_amd64" {
  value       = "http://${module.alb_amd64.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}

output "application_url_arm64" {
  value       = "http://${module.alb_arm64.dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}
