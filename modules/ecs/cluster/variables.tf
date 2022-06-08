# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The cluster namespace"
  type        = string
}

variable "container_insights" {
  description = "Whether or not Container Insights is enabled."
  type        = bool
  default     = true
}

variable "tags" {
  description = "tags"
  type        = map(string)
}
