# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*=========================================
      AWS Elastic Container Repository
==========================================*/

resource "aws_ecr_repository" "ecr_repository" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  tags = var.tags

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}