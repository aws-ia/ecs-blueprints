provider "aws" {
  region = local.region
}
locals {
  name                   = "ecs-demo-triton-inference"
  region                 = "us-west-2"
  triton_instance_type   = "g5.12xlarge"
  triton_container_image = "ecs-blueprint-triton-inference:0.1"

  user_data = <<-EOT
#!/bin/bash
cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${local.name}
EOF
echo "ip_resolve=4" >> /etc/yum.conf

yum install amazon-cloudwatch-agent -y
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "agent": {
        "metrics_collection_interval": 1,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "EcsBlueprints/DistributedInferenceRay",
        "metrics_collected": {
            "mem": {
                "measurement": [
                        "mem_used_percent"
                ]
            },
            "nvidia_gpu": {
                "measurement": [
                    "utilization_gpu",
                    "utilization_memory",
                    "memory_total",
                    "memory_used",
                    "memory_free",
                    "clocks_current_graphics",
                    "clocks_current_sm",
                    "clocks_current_memory"
                ]
            }
        },
        "append_dimensions": {
            "InstanceId": "$${aws:InstanceId}"
        }
    }
}

EOF

systemctl enable --now amazon-cloudwatch-agent.service

cat << EOF > model.json
{
    "model":"TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "gpu_memory_utilization": 0.9,
    "tensor_parallel_size": 4
}

EOF

cat << EOF > config.pbtxt
backend: "vllm"

# The usage of device is deferred to the vLLM engine
instance_group [
  {
    count: 1
    kind: KIND_MODEL
  }
]

EOF

cat << 'EOF' > Dockerfile
FROM nvcr.io/nvidia/tritonserver:23.11-vllm-python-py3
RUN mkdir -p /opt/tritonserver/model_repository/vllm_model/1/
COPY config.pbtxt /opt/tritonserver/model_repository/vllm_model/
COPY model.json /opt/tritonserver/model_repository/vllm_model/1/

EOF

docker build -t ecs-blueprint-triton-inference:0.1 .

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
  # Capacity provider - autoscaling group
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    triton = {
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
  image_id                        = jsondecode(data.aws_ssm_parameter.ecs_gpu_optimized_ami.value)["image_id"]
  instance_type                   = local.triton_instance_type
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
        volume_size           = 200   # 100GB storage
        volume_type           = "gp3" # General Purpose SSD (gp3 is recommended over gp2)
        delete_on_termination = true
        encrypted             = true
      }
    }
  ]
  tags = local.tags
}

################################################################################
# ECS Task Definition for triton
################################################################################

resource "aws_ecs_task_definition" "triton" {
  family                   = "triton-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([
    {
      name   = "triton"
      image  = local.triton_container_image
      cpu    = 32768
      memory = 65536
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
          }, {
          containerPort = 8001
          hostPort      = 8001
          protocol      = "tcp"
          }, {
          containerPort = 8002
          hostPort      = 8002
          protocol      = "tcp"
        }
      ]
      environment = [

      ]
      command = ["/bin/bash", "-lc", "--",
      "tritonserver --model-repository=./model-repository"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/${local.name}"
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
      essential = true
      linuxParameters = {
        sharedMemorySize = 4096
      }
      environment = [
        {
          name  = "NCCL_DEBUG"
          value = "INFO"
        }
      ]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "4"
        }
      ]

      ulimits = [
        {
          name      = "memlock"
          softLimit = -1
          hardLimit = -1
        },
        {
          name      = "stack"
          softLimit = 67108864
          hardLimit = 67108864
        }
      ]

    }
  ])

  tags = {
    app = "triton"
  }
}

################################################################################
# ALB Configuration
################################################################################

resource "aws_lb" "triton" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.security_group_id]
  subnets            = data.aws_subnets.public.ids

  tags = local.tags
}

resource "aws_lb_target_group" "triton" {
  name        = "${local.name}-tg"
  protocol    = "HTTP"
  port        = 8000
  target_type = "ip"
  vpc_id      = data.aws_vpc.core_infra.id

  health_check {
    path                = "/v2/health/ready"
    interval            = 180
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_listener" "triton" {
  load_balancer_arn = aws_lb.triton.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.triton.arn
  }

  tags = local.tags
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "triton" {
  name            = "triton-service"
  cluster         = module.ecs_cluster.id
  task_definition = aws_ecs_task_definition.triton.arn
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnets.private.ids
    security_groups = [module.autoscaling_sg.security_group_id]
  }

  capacity_provider_strategy {
    capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["triton"].name
    weight            = 1
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.triton.arn
    container_name   = "triton"
    container_port   = 8000
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################
data "aws_ssm_parameter" "ecs_gpu_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended"
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
