output "application_url_amd64" {
  value       = "http://${module.service_alb.lb_dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}

output "application_url_arm64" {
  value       = "http://${module.service_alb_arm.lb_dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}
