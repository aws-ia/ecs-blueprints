# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "service_arn" {
  description = "The ECS Service ARN"
  value       = aws_ecs_service.main.id
}
