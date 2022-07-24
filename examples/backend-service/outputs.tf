
output "service_discovery_url" {
  value       = "${aws_service_discovery_service.sd_service.arn}"
  description = "Copy this value in your browser in order to access the deployed app"
}


