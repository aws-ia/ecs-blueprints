# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*====================================
      AWS ECS Task definition
=====================================*/

resource "aws_ecs_task_definition" "main" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role
  task_role_arn            = var.task_role

  container_definitions = jsonencode([
    {
      cpu : var.cpu,
      memory : var.memory,
      image : var.image,
      name : var.container_name,
      networkMode : "awsvpc",
      portMappings : [
        {
          protocol : "tcp",
          containerPort : var.container_port,
          hostPort : var.container_port
        }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          awslogs-region : var.region,
          awslogs-group : var.cloudwatch_log_group,
          awslogs-stream-prefix : "ecs"
        }
      }
    }
  ])
}
