output "cluster_name" {
  value       = module.ecs_cluster.name
  description = "ECS cluster created by this example"
}

output "source_s3_bucket" {
  value       = module.source_s3_bucket.s3_bucket_id
  description = "Source S3 Bucket for data pipeline processing"
}

output "destination_s3_bucket" {
  value       = module.destination_s3_bucket.s3_bucket_id
  description = "Destination S3 Bucket for processed files"
}

output "queue_url" {
  value       = module.sqs.queue_url
  description = "URL of the SQS queue receiving S3 upload notifications"
}
