# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "The family name of the task definition"
  value       = aws_ecs_task_definition.main.family
}
