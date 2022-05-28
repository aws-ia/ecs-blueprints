# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name of your Dynamodb table"
  type        = string
}

variable "hash_key" {
  description = "The identifier of your hash key"
  type        = string
  default     = "id"
}

variable "range_key" {
  description = "The identifier of your range key"
  type        = string
  default     = null
}

variable "attributes" {
  description = "A set of atributes names and types that compone the table"
  type        = list(object({ name = string, type = string }))
  default = [
    {
      name = "id",
      type = "N",
    }
  ]
}
