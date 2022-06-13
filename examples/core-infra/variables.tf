# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "aws_profile" {
  description = "The profile name that you have configured in the file .aws/credentials"
  type        = string
}

variable "aws_region" {
  description = "The AWS Region in which you want to deploy the resources"
  type        = string
}

variable "environment_name" {
  description = "The name of your environment"
  type        = string

  validation {
    condition     = length(var.environment_name) < 23
    error_message = "Due the this variable is used for concatenation of names of other resources, the value must have less than 23 characters."
  }
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
}
