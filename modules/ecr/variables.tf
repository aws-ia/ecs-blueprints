# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name of your ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (defaults to IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "tags" {
  description = "tags"
  type        = map(string)
}
