# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "sg_id" {
  description = "The ID of the security group"
  value       = aws_security_group.sg.id
}
