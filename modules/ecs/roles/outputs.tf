# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "execution_role" {
  description = "The task execution role arn"
  value       = aws_iam_role.execution.arn
}

output "task_role" {
  description = "The task role arn"
  value       = aws_iam_role.task.arn
}
