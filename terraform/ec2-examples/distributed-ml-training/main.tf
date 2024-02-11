provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name                       = "ecs-demo-distributed-ml-training"
  region                     = "us-west-2"
  instance_type_workers      = "g5.xlarge"
  instance_type_head         = "m5.xlarge"
  ray_head_container_image   = "docker.io/rayproject/ray-ml:2.7.1.artur.c9f4c6-py38"
  ray_worker_container_image = "docker.io/rayproject/ray-ml:2.7.1.artur.c9f4c6-py38-gpu"

  user_data_head = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    EOF
  EOT

  user_data_workers = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    EOF
    echo "ip_resolve=4" >> /etc/yum.conf
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
    distributed_ml_training_head = {
      auto_scaling_group_arn = module.autoscaling_head.autoscaling_group_arn

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
    distributed_ml_training_workers = {
      auto_scaling_group_arn = module.autoscaling_workers.autoscaling_group_arn
      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        _scaling_step_size        = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }
    },
  }

  # Shared task execution role
  create_task_exec_iam_role = false
  tags                      = local.tags
}

resource "aws_service_discovery_service" "this" {
  name = "head"
  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.core_infra.id
    dns_records {
      ttl  = 300
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}


resource "aws_placement_group" "workers" {
  name     = "ml-training"
  strategy = "cluster"
}

module "autoscaling_head" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name = "${local.name}-head"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = local.instance_type_head

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data_head)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role      = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
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

  tags = local.tags

  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

module "autoscaling_workers" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name = "${local.name}-workers"

  placement_group = aws_placement_group.workers.name
  image_id        = jsondecode(data.aws_ssm_parameter.ecs_gpu_optimized_ami.value)["image_id"]
  instance_type   = local.instance_type_workers

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data_workers)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role      = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  }

  vpc_zone_identifier = data.aws_subnets.private.ids
  health_check_type   = "EC2"
  min_size            = 2
  max_size            = 2
  desired_capacity    = 2

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
        volume_size           = 50
        volume_type           = "gp2"
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

  egress_rules = ["all-all"]

  tags = local.tags
}


module "ecs_service_head" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = "distributed_ml_training_head_service"
  desired_count      = 1
  cluster_arn        = module.ecs_cluster.arn
  enable_autoscaling = false
  memory             = 10240
  cpu                = 3072
  # Task Definition

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["distributed_ml_training_head"].name # needs to match name of capacity provider
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
  tasks_iam_role_statements = [
    {
      actions = ["s3:*"]
      resources = [
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}/*"
      ]
    }
  ]
  create_task_exec_iam_role          = false
  enable_execute_command             = false
  deployment_minimum_healthy_percent = 0
  container_definitions = {

    ray_head = {
      readonly_root_filesystem = false
      image                    = local.ray_head_container_image
      user                     = 1000
      cpu                      = 3072
      memory                   = 10240
      memory_reservation       = 10240
      command                  = ["/bin/bash", "-lc", "--", "ulimit -n 65536; ray start --head --dashboard-host=0.0.0.0 --metrics-export-port=8080 --num-cpus=0 --memory=10737418240 --block"]
      linux_parameters = {
        sharedMemorySize = 20480
      }
      mount_points = [{
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  volume = {
    "tmp" = {
      dockerVolumeConfiguration = {
        scope         = "shared",
        driver        = "local",
        autoprovision = true
      }
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
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


module "ecs_service_workers" {
  source                             = "terraform-aws-modules/ecs/aws//modules/service"
  version                            = "~> 5.0"
  deployment_minimum_healthy_percent = 0
  name                               = "distributed_ml_training_worker_service"
  desired_count                      = 2
  cluster_arn                        = module.ecs_cluster.arn
  enable_autoscaling                 = false
  memory                             = 15360
  cpu                                = 3072
  # Task Definition

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["distributed_ml_training_workers"].name # needs to match name of capacity provider
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
  tasks_iam_role_statements = [
    {
      actions = ["s3:*"]
      resources = [
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}/*"
      ]
    }
  ]

  create_task_exec_iam_role = false
  enable_execute_command    = false

  container_definitions = {
    ray_work = {
      readonly_root_filesystem = false
      image                    = local.ray_worker_container_image
      user                     = 1000
      cpu                      = 3072
      memory                   = 15360
      memory_reservation       = 15360
      command                  = ["/bin/bash", "-lc", "--", "ulimit -n 65536; ray start --block --num-cpus=3 --num-gpus=1 --address=head.default.core-infra.local:6379 --metrics-export-port=8080 --memory=15032385536"]
      linux_parameters = {
        sharedMemorySize = 10240
      }
      resource_requirements = [{
        type  = "GPU"
        value = 1
      }]
      mount_points = [{
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  volume = {
    "tmp" = {
      dockerVolumeConfiguration = {
        scope         = "shared",
        driver        = "local",
        autoprovision = true
      }
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

resource "random_id" "bucket_name" {
  byte_length = 8
}

resource "aws_s3_bucket" "results" {
  bucket        = "dt-results-${random_id.bucket_name.hex}"
  tags          = local.tags
  force_destroy = true
}

resource "aws_iam_role" "task_execution_role" {
  name = "distributed_training_task_execution_role"

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

################################################################################
# Supporting Resources
################################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

data "aws_ssm_parameter" "ecs_gpu_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["core-infra-private-${local.region}a"]
  }
}

data "aws_vpc" "core_infra" {
  filter {
    name   = "tag:Name"
    values = ["core-infra"]
  }
}

data "aws_service_discovery_dns_namespace" "core_infra" {
  name = "default.core-infra.local"
  type = "DNS_PRIVATE"
}
