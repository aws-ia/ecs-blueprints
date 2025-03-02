################################################################################
# VPC
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "A list of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "A list of private subnets for the client app"
  value       = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  description = "A list of private subnets CIDRs"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "private_subnet_objects" {
  description = "A list of private subnets objects"
  value       = module.vpc.private_subnet_objects
}

output "default_vpc_cidr" {
  description = "The CIDR of the default VPC"
  value       = local.default_vpc_cidr_block
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

output "service_discovery_namespaces" {
  description = "Service discovery namespaces already available"
  value       = aws_service_discovery_private_dns_namespace.this
}

output "service_discovery_namespace_id" {
  description = "Service discovery namespace id"
  value       = aws_service_discovery_private_dns_namespace.this.id
}

################################################################################
# Security Groups
################################################################################
output "fargate_container_security_group_id" {
  description = "The ID of the security group for Fargate containers"
  value       = aws_security_group.fargate_containers.id
}
