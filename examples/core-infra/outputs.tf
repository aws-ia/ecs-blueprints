# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "aws_vpc" {
  description = "The ID of the VPC"
  value       = module.networking.aws_vpc
}

output "public_subnets" {
  description = "A list of public subnets"
  value       = module.networking.public_subnets
}
output "private_subnets_client" {
  description = "A list of private subnets for the client app"
  value       = module.networking.private_subnets_client
}

output "private_subnets_server" {
  description = "A list of private subnets for the server app"
  value       = module.networking.private_subnets_server
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = module.ecs_cluster.id
}
