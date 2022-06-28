output "application_url" {
  value       = module.client_alb.lb_dns_name
  description = "Copy this value in your browser in order to access the deployed app"
}

output "swagger_endpoint" {
  value       = "${module.server_alb.lb_dns_name}/api/docs"
  description = "Copy this value in your browser in order to access the swagger documentation"
}
