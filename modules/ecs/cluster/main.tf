# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*=============================
        AWS ECS Cluster
===============================*/

resource "aws_ecs_cluster" "main" {
  name = var.name
  tags = var.tags
  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }
}
