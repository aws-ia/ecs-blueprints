# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "The name of your security group"
  type        = string
}

variable "description" {
  description = "A description of the purpose"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the security group will take place"
  type        = string
}

variable "ingress_port" {
  description = "Number of the port to open in the ingress rules"
  type        = number
  default     = 0
}

variable "egress_port" {
  description = "Number of the port to open in the egress rules"
  type        = number
  default     = 0
}

variable "security_groups" {
  description = "List of security group Group Names if using EC2-Classic, or Group IDs if using a VPC"
  type        = list(any)
  default     = null
}

variable "cidr_blocks_ingress" {
  description = "An ingress block of CIDR to grant access to"
  type        = list(any)
  default     = null
}

variable "cidr_blocks_egress" {
  description = "An ingress block of CIDR to grant access to"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}
