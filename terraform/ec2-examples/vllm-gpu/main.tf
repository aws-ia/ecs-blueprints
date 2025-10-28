provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name            = "ecs-demo-vllm-gpu"
  region          = "us-west-2"
  instance_type   = "g5.12xlarge"
  container_image = "vllm/vllm-openai:v0.10.2"
  container_port  = 8000

  user_data = <<-EOT
#!/bin/bash
cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${local.name}
EOF
echo "ip_resolve=4" >> /etc/yum.conf
mkdir -p /opt/model_cache/huggingface
yum install amazon-cloudwatch-agent -y
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "agent": {
        "metrics_collection_interval": 1,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "EcsBlueprints/vllm",
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


  EOT

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}


################################################################################
# ECS Blueprint
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  cluster_name = local.name
  # Capacity provider - autoscaling groups
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    vllm_inference = {
      auto_scaling_group_arn = module.autoscaling_vllm.autoscaling_group_arn

      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    },
  }

  # Shared task execution role
  create_task_exec_iam_role = false
  tags                      = local.tags
}

module "autoscaling_vllm" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name          = local.name
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_gpu_optimized_ami.value)["image_id"]
  instance_type = local.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role      = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
    CloudWatchAgentServerPolicy              = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  vpc_zone_identifier = data.aws_subnets.private.ids
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 200
        volume_type           = "gp3"
      }
    }
  ]
  tags = local.tags

  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = data.aws_vpc.core_infra.id

  ingress_with_cidr_blocks = [
    {
      from_port   = -1
      to_port     = -1
      protocol    = -1
      description = "Allow all from VPC CIDR block"
      cidr_blocks = data.aws_vpc.core_infra.cidr_block
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = -1
      to_port     = -1
      protocol    = -1
      description = "Allow all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}


module "ecs_service_vllm" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = "vllm_inference_service"
  desired_count      = 1
  cluster_arn        = module.ecs_cluster.arn
  enable_autoscaling = false
  #memory             = 127555
  memory = 184320
  cpu    = 10240
  # Task Definition

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["vllm_inference"].name # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  task_exec_iam_role_arn     = aws_iam_role.task_execution_role.arn
  tasks_iam_role_name        = "taskRole"
  tasks_iam_role_description = "Task role for ${local.name}"
  tasks_iam_role_policies = {
    ReadOnlyAccess = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  }
  tasks_iam_role_statements          = []
  create_task_exec_iam_role          = false
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 0
  container_definitions = {

    vllm = {
      readonly_root_filesystem = false
      image                    = local.container_image
      cpu                      = 10240
      memory                   = 184320
      memory_reservation       = 184320
      command                  = ["--tensor-parallel-size", "4", "--model", "unsloth/Meta-Llama-3.1-8B-Instruct"]
      linux_parameters = {
        sharedMemorySize = 20480
      }
      environment = [
        {
          name  = "HF_HUB_CACHE"
          value = "/.cache/huggingface/hub"
        }
      ]
      resource_requirements = [{
        type  = "GPU"
        value = 4
      }]
      mount_points = [{
        sourceVolume  = "cache_huggingface"
        containerPath = "/.cache/huggingface/hub"
        readOnly      = false
      }]
      port_mappings = [
        {
          protocol      = "tcp",
          containerPort = local.container_port
        }
      ]
    }
  }
  volume = {
    "cache_huggingface" = {
      host_path = "/opt/model_cache/huggingface"
    }
  }

  network_mode = "awsvpc"
  subnet_ids   = data.aws_subnets.private.ids
  security_group_rules = {
    ingress_private_ips = {
      type        = "ingress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = local.tags
}


resource "aws_iam_role" "task_execution_role" {
  name = "vllm_task_execution_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ECSTasksAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : data.aws_caller_identity.current.account_id
          },
          "ArnLike" : {
            "aws:SourceArn" : "arn:aws:ecs:${local.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
  tags = local.tags
}

resource "aws_cloudwatch_dashboard" "vllm_dashboard" {
  dashboard_name = "vllm-inference"

  dashboard_body = jsonencode({
    "widgets" : [
      {
        "height" : 7,
        "width" : 12,
        "y" : 0,
        "x" : 0,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            [
              "EcsBlueprints/vllm",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[0],
              "name",
              "NVIDIA A10G",
              "index",
              "3",
              "arch",
              "Ampere",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "EcsBlueprints/vllm",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[0],
              "name",
              "NVIDIA A10G",
              "index",
              "2",
              "arch",
              "Ampere",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "EcsBlueprints/vllm",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[0],
              "name",
              "NVIDIA A10G",
              "index",
              "0",
              "arch",
              "Ampere",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "EcsBlueprints/vllm",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[0],
              "name",
              "NVIDIA A10G",
              "index",
              "1",
              "arch",
              "Ampere",
              {
                "region" : "us-west-2"
              }
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : "us-west-2",
          "title" : "${data.aws_instances.tagged_instances.ids[0]} - GPU memory utilization (GB)",
          "period" : 60,
          "stat" : "Average"
          "start" : "-PT60M",
          "end" : "P0D"
        }
      },
      {
        "height" : 7,
        "width" : 12,
        "y" : 0,
        "x" : 12,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            [
              "EcsBlueprints/vllm",
              "nvidia_smi_utilization_gpu",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[0],
              "name",
              "NVIDIA A10G",
              "index",
              "0",
              "arch",
              "Ampere",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "...",
              "2",
              ".",
              ".",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "...",
              "3",
              ".",
              ".",
              {
                "region" : "us-west-2"
              }
            ],
            [
              "...",
              "1",
              ".",
              ".",
              {
                "region" : "us-west-2"
              }
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : "us-west-2",
          "title" : "${data.aws_instances.tagged_instances.ids[0]} - GPU utilization percentage",
          "period" : 60,
          "stat" : "Average",
          "start" : "-PT60M",
          "end" : "P0D"
        }
      }
    ]
  })
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
    values = ["core-infra-private-${local.region}b"]
  }
}

data "aws_vpc" "core_infra" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}

resource "null_resource" "wait_for_instance" {
  depends_on = [
    module.autoscaling_vllm
  ]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "${path.module}/check_instance_state.sh ${local.name}"
  }
}

data "aws_instances" "tagged_instances" {
  depends_on = [
    null_resource.wait_for_instance
  ]
  filter {
    name   = "tag:Blueprint"
    values = [local.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}
