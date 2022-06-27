# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Provided name used for name concatenation of resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block"
  type        = list(any)
}
