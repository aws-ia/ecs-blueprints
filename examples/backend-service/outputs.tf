# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "service" {
  description = "The ECS Service ARN"
  value       = module.service.service_arn
}
