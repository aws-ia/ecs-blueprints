output "application_url" {
  description = "IPv6 public endpoint. The client must have IPv6 connectivity."
  value       = "http://${module.alb.dns_name}"
}

output "private_ipv6_subnet_ids" {
  description = "IPv6-native subnets used by Fargate tasks."
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_cluster.name
}
