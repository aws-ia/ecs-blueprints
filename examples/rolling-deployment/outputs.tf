output "application_s3_bucket" {
  value       = module.assets_s3_bucket.s3_bucket_id
  description = "Use the s3 bucket to copy the assets for the application"
}

output "application_dynamodb_table" {
  value       = module.assets_dynamodb_table.dynamodb_table_id
  description = "Use the dynamo db table to populate application"
}

output "application_url" {
  value       = "http://${module.client_alb.lb_dns_name}"
  description = "Copy this value in your browser in order to access the deployed app"
}

output "swagger_endpoint" {
  value       = "http://${module.server_alb.lb_dns_name}/api/docs"
  description = "Copy this value in your browser in order to access the swagger documentation"
}
