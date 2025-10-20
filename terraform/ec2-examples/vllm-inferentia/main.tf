provider "aws" {
  region = local.region
}
locals {
  name                 = "ecs-demo-vllm-inferentia" # Defaul name of the project
  region               = "us-west-2"                # Default region
  instance_type        = "inf2.8xlarge"             # Default instance size - if you change this - you will need to modify the cpu/memory details in the task definition
  vllm_container_image = "public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.9.1-neuronx-py311-sdk2.26.0-ubuntu22.04"
  user_data            = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_ENABLE_CONTAINER_METADATA=true
    ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
    EOF
  EOT
  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}
################################################################################
################################################################################
# ECS Blueprint
################################################################################
################################################################################


################################################################################
# ALB Security Group
################################################################################

module "alb_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 4.0"
  name        = "${local.name}-alb"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.core_infra.id
  ingress_with_cidr_blocks = [
    {
      from_port   = 8000
      to_port     = 8000
      protocol    = "tcp"
      description = "Allow public HTTP traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules = ["all-all"]
  tags         = local.tags
}

################################################################################
# ECS Task / Autoscaling Security Group
################################################################################
module "autoscaling_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 4.0"
  name        = "${local.name}-ecs-tasks"
  description = "Autoscaling group security group"
  vpc_id      = data.aws_vpc.core_infra.id
  ingress_with_source_security_group_id = [
    {
      from_port                = 8000
      to_port                  = 8000
      protocol                 = "tcp"
      description              = "Allow traffic from ALB"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]
  tags         = local.tags
}

################################################################################
# ECS Cluster
################################################################################
# Cluster Config
module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws//modules/cluster"
  version      = "~> 5.0"
  cluster_name = local.name
  cluster_settings = [{
    name  = "containerInsights",
    value = "enhanced"
  }]
  # Capacity provider - autoscaling group
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    vllm = {
      auto_scaling_group_arn = module.autoscaling.autoscaling_group_arn
      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 100
      }
      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
  }
  tags = local.tags
}

# Austocaling Policy
module "autoscaling" {
  source                          = "terraform-aws-modules/autoscaling/aws"
  version                         = "~> 6.5"
  name                            = "${local.name}-asg"
  image_id                        = jsondecode(data.aws_ssm_parameter.ecs_neuron_optimized_ami.value)["image_id"]
  instance_type                   = local.instance_type
  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true
  create_iam_instance_profile     = true
  iam_role_name                   = local.name
  iam_role_description            = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  vpc_zone_identifier = data.aws_subnets.private.ids
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }
  # Configure block device mapping
  block_device_mappings = [
    {
      device_name = "/dev/xvda" # Root volume device name
      ebs = {
        volume_size           = 100   # 100GB storage
        volume_type           = "gp3" # General Purpose SSD (gp3 is recommended over gp2)
        delete_on_termination = true
        encrypted             = true
      }
    }
  ]
  tags = local.tags
}

################################################################################
# ECS Task Definition for VLLM
################################################################################

resource "aws_ecs_task_definition" "neuronx_vllm" {
  family                   = "neuronx-vllm-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([
    {
      name   = "neuronx-vllm"
      image  = local.vllm_container_image
      cpu    = 32768
      memory = 65536
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "VLLM_NEURON_FRAMEWORK"
          value = "neuronx-distributed-inference"
        },
        {
          name  = "NEURON_COMPILE_CACHE_URL"
          value = "/neuron-compile-cache"
        }
      ]
      command = [
        "python",
        "-m",
        "vllm.entrypoints.openai.api_server",
        "--model", "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
        "--max-num-seqs", "4",
        "--max-model-len", "128",
        "--tensor-parallel-size", "2",
        "--port", "8000",
        "--device", "neuron"
      ]
      mountPoints = [
        {
          sourceVolume  = "neuron-compile-cache-volume"
          containerPath = "/neuron-compile-cache"
          readOnly      = false
        }
      ]
      linuxParameters = {
        devices = [
          {
            containerPath = "/dev/neuron0"
            hostPath      = "/dev/neuron0"
            permissions   = ["read", "write"]
          }
        ]
        capabilities = {
          add = ["IPC_LOCK", "SYS_ADMIN"]
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/${local.name}"
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
      essential = true
    }
  ])
  volume {
    name      = "neuron-compile-cache-volume"
    host_path = "/opt/cache/neuron-compile"
  }
  tags = {
    app = "neuronx-vllm"
  }
}

################################################################################
# ALB Configuration
################################################################################

resource "aws_lb" "vllm" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.security_group_id]
  subnets            = data.aws_subnets.public.ids

  tags = local.tags
}

resource "aws_lb_target_group" "vllm" {
  name        = "${local.name}-tg"
  protocol    = "HTTP"
  port        = 8000
  target_type = "ip"
  vpc_id      = data.aws_vpc.core_infra.id

  health_check {
    path                = "/health"
    interval            = 180
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_listener" "vllm" {
  load_balancer_arn = aws_lb.vllm.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vllm.arn
  }

  tags = local.tags
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "neuronx_vllm" {
  name            = "neuronx-vllm-service"
  cluster         = module.ecs_cluster.id
  task_definition = aws_ecs_task_definition.neuronx_vllm.arn
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnets.private.ids
    security_groups = [module.autoscaling_sg.security_group_id]
  }

  capacity_provider_strategy {
    capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["vllm"].name
    weight            = 1
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.vllm.arn
    container_name   = "neuronx-vllm"
    container_port   = 8000
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################
data "aws_ssm_parameter" "ecs_neuron_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/neuron/recommended"
}
data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-${local.region}*"]
  }
}
data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-public-${local.region}*"] # Update to match your naming convention
  }
}
data "aws_vpc" "core_infra" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}
