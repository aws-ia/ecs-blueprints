################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "ARN that identifies the cluster"
  value       = module.ecs_cluster.arn
}

################################################################################
# S3
################################################################################

output "s3_bucket" {
  description = "Bucket name for results"
  value       = aws_s3_bucket.results.id
}
