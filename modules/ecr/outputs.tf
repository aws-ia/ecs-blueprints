# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "ecr_repository_url" {
  description = "The URL of the created ECR repository"
  value       = aws_ecr_repository.ecr_repository.repository_url
}

output "ecr_repository_arn" {
  description = "The ARN of the created ECR repository"
  value       = aws_ecr_repository.ecr_repository.arn
}
