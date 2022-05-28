# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "ecs_cluster_name" {
  description = "The name of the ECS Cluster"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_cluster_id" {
  description = "The ID/ARN of the ECS Cluster"
  value       = aws_ecs_cluster.ecs_cluster.id
}
