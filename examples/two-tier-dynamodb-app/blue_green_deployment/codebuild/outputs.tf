# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "project_id" {
  description = "The ID of the CodeBuild project"
  value       = aws_codebuild_project.aws_codebuild.id
}

output "project_arn" {
  description = "The ARN of the CodeBuild project"
  value       = aws_codebuild_project.aws_codebuild.arn
}
