output "application_s3_bucket" {
  value       = module.assets_s3_bucket.s3_bucket_id
  description = "Use the s3 bucket to copy the assets for the application"
}

output "application_url" {
  value       = "http://${module.service_alb.lb_dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}


