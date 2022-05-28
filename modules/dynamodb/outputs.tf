# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "dynamodb_table_arn" {
  description = "The ARN of the created Dynamodb table"
  value       = aws_dynamodb_table.dynamodb_table.arn
}

output "dynamodb_table_name" {
  description = "The nem of the created Dynamodb table"
  value       = aws_dynamodb_table.dynamodb_table.name
}
