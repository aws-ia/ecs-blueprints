# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "arn_role" {
  description = "The ARN of the IAM role"
  value = (var.create_ecs_role == true
    ? (length(aws_iam_role.ecs_task_excecution_role) > 0 ? aws_iam_role.ecs_task_excecution_role[0].arn : "")
  : (length(aws_iam_role.devops_role) > 0 ? aws_iam_role.devops_role[0].arn : ""))
}

output "name_role" {
  description = "The name of the IAM role"
  value = (var.create_ecs_role == true
    ? (length(aws_iam_role.ecs_task_excecution_role) > 0 ? aws_iam_role.ecs_task_excecution_role[0].name : "")
  : (length(aws_iam_role.devops_role) > 0 ? aws_iam_role.devops_role[0].name : ""))
}

output "arn_role_codedeploy" {
  description = "The ARN of the CodeDeploy IAM role"
  value = (var.create_codedeploy_role == true
    ? (length(aws_iam_role.codedeploy_role) > 0 ? aws_iam_role.codedeploy_role[0].arn : "")
  : "")
}

output "arn_role_ecs_task_role" {
  description = "The ARN of the IAM role for the ECS task role"
  value = (var.create_ecs_role == true
    ? (length(aws_iam_role.ecs_task_role) > 0 ? aws_iam_role.ecs_task_role[0].arn : "")
  : "")
}
