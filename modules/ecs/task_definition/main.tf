# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*====================================
      AWS ECS Task definition
=====================================*/

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "task-definition-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = <<DEFINITION
    [
      {
        "logConfiguration": {
            "logDriver": "awslogs",
            "secretOptions": null,
            "options": {
              "awslogs-group": "/ecs/task-definition-${var.name}",
              "awslogs-region": "${var.region}",
              "awslogs-stream-prefix": "ecs"
            }
          },
        "cpu": 0,
        "image": "${var.docker_repo}",
        "name": "${var.container_name}",
        "networkMode": "awsvpc",
        "portMappings": [
          {
            "containerPort": ${var.container_port},
            "hostPort": ${var.container_port}
          }
        ]
        }
    ]
    DEFINITION
}

# ------- CloudWatch Logs groups to store ecs-containers logs -------
resource "aws_cloudwatch_log_group" "TaskDF-Log_Group" {
  name              = "/ecs/task-definition-${var.name}"
  retention_in_days = 30
}
