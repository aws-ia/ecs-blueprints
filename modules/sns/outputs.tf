# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "sns_arn" {
  description = "The ARN of the SNS topic"
  value       = aws_sns_topic.sns_notification.arn
}
