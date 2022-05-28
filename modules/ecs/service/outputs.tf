# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "ecs_service_name" {
  description = "The name of the ECS Service"
  value       = aws_ecs_service.ecs_service.name
}
