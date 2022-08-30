output "source_s3_bucket" {
  value       = module.source_s3_bucket.s3_bucket_id
  description = "Source S3 Bucket for data pipeline processing"
}

output "destination_s3_bucket" {
  value       = module.destination_s3_bucket.s3_bucket_id
  description = "Destination S3 Bucket for processed files"
}
