################################################################################
# ECS
################################################################################

output "ecs_cluster" {
  description = "ECS Cluster for distributed inference"
  value       = module.ecs_cluster.arn
}
