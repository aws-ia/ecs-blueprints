# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*================================
      AWS Security group
=================================*/

resource "aws_security_group" "sg" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.ingress_port
    to_port         = var.ingress_port
    cidr_blocks     = var.cidr_blocks_ingress
    security_groups = var.security_groups
  }
  egress {
    from_port   = var.egress_port
    to_port     = var.egress_port
    protocol    = "-1"
    cidr_blocks = var.cidr_blocks_egress
  }

  tags = {
    Name = var.name
  }
}
