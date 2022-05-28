# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "arn_task_definition" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.ecs_task_definition.arn
}

output "task_definition_family" {
  description = "The family name of the task definition"
  value       = aws_ecs_task_definition.ecs_task_definition.family
}
