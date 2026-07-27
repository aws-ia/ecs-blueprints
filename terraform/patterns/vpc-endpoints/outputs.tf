output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the VPC (no internet gateway or NAT gateway)"
}

output "vpc_endpoints" {
  value       = { for k, v in module.vpc_endpoints.endpoints : k => v.id }
  description = "Map of VPC endpoint names to endpoint IDs"
}

output "cluster_name" {
  value       = module.ecs_cluster.name
  description = "Name of the ECS cluster"
}

output "cached_image" {
  value       = local.cached_image
  description = "Private ECR pull-through cache image URI the service pulls through the VPC endpoints"
}
