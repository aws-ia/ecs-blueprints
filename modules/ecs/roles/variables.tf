# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name"
  type        = string
}

variable "task_role_policy" {
  description = "The task's role policy"
  type        = string
}
