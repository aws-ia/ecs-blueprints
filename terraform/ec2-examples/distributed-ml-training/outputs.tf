################################################################################
# VPC
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "A list of private subnets for the client app"
  value       = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  description = "A list of private subnets CIDRs"
  value       = module.vpc.private_subnets_cidr_blocks
}

################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "ARN that identifies the cluster"
  value       = module.ecs_cluster.arn
}

output "cluster_id" {
  description = "ID that identifies the cluster"
  value       = module.ecs_cluster.id
}

output "cluster_name" {
  description = "Name that identifies the cluster"
  value       = module.ecs_cluster.name
}


################################################################################
# S3
################################################################################

output "s3_bucket" {
  description = "ARN that identifies the bucket for results"
  value       = aws_s3_bucket.results.arn
}
