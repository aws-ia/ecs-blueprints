provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = "ecs-demo-distributed-ml-training"
  region = "us-east-1"

  vpc_cidr                   = "10.0.0.0/16"
  azs                        = slice(data.aws_availability_zones.available.names, 0, 1)
  instance_type_workers      = "g5.12xlarge"
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

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "default.${local.name}.local"
  description = "Service discovery namespace.clustername.local"
  vpc         = module.vpc.vpc_id
  tags        = local.tags
}

resource "aws_service_discovery_service" "this" {
  name = "head"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      ttl  = 300
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.2.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = false

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  tags = local.tags
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

data "aws_ssm_parameter" "ecs_gpu_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
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
    AmazonElasticFileSystemClientFullAccess  = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  tags = local.tags
}

module "autoscaling_workers" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name = "${local.name}-workers"

  #image_id      = data.aws_ssm_parameter.ecs_bottlerocket_gpu_optimized_ami.value
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_gpu_optimized_ami.value)["image_id"]
  instance_type = local.instance_type_workers

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

  vpc_zone_identifier = module.vpc.private_subnets
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
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name                = local.name
  description         = "Autoscaling group security group"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]

  ingress_rules = ["all-all"]

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
      capacity_provider = "distributed_ml_training_head" # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  task_exec_iam_role_arn     = aws_iam_role.task_execution_role.arn
  tasks_iam_role_name        = "dt-role-tasks"
  tasks_iam_role_description = "Tasks IAM role for ${local.name}"
  tasks_iam_role_policies = {
    AmazonElasticFileSystemClientFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
  }
  create_task_exec_iam_role          = false
  enable_execute_command             = false
  deployment_minimum_healthy_percent = 0
  container_definitions = {

    ray_head = {
      readonly_root_filesystem = true
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
        sourceVolume  = "ray_results"
        containerPath = "/home/ray/ray_results"
        readOnly      = false
      },
      {
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  volume = {
    "tmp" = {
      docker_volume_configuration = {
        scope = "task"
        driver = "local"
      }
    }
    "ray_results" = {
      efs_volume_configuration = {
        file_system_id     = module.efs.id,
        root_directory     = "/"
        transit_encryption = "ENABLED",
        authorization_config = {
          access_point_id = module.efs.access_points.ray_results.id
          iam             = "ENABLED"
        }
      }
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.this.arn
  }

  network_mode = "awsvpc"
  subnet_ids   = module.vpc.private_subnets
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
  memory                             = 189440
  cpu                                = 10240
  # Task Definition

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = "distributed_ml_training_workers" # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  task_exec_iam_role_arn     = aws_iam_role.task_execution_role.arn
  tasks_iam_role_name        = "dt-role-tasks"
  tasks_iam_role_description = "Tasks IAM role for ${local.name}"
  tasks_iam_role_policies = {
    AmazonElasticFileSystemClientFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
  }
  create_task_exec_iam_role = false
  enable_execute_command    = false

  container_definitions = {
    ray_work = {
      readonly_root_filesystem = true
      image                    = local.ray_worker_container_image
      user                     = 1000
      cpu                      = 10240
      memory                   = 189440
      memory_reservation       = 189440
      command                  = ["/bin/bash", "-lc", "--", "ray start --block --num-cpus=10 --num-gpus=4 --address=head.default.ecs-demo-distributed-ml-training.local:6379 --metrics-export-port=8080 --memory=198642237440"]
      linux_parameters = {
        sharedMemorySize = 20480
      }
      resource_requirements = [{
        type  = "GPU"
        value = 4
      }]
      mount_points = [{
        sourceVolume  = "ray_results"
        containerPath = "/home/ray/ray_results"
        readOnly      = false
      },
      {
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  # We are using network=host because there will be a single container in each host with GPUs. There is less overhead when using a single container with
  # access to all 4 GPUs available in g5.12xlarge than 4 containers with 1 GPU each.
  network_mode = "host"

  volume = {
     "tmp" = {
      docker_volume_configuration = {
        scope = "task"
        driver = "local"
      }
    }
    "ray_results" = {
      efs_volume_configuration = {
        file_system_id     = module.efs.id,
        root_directory     = "/"
        transit_encryption = "ENABLED",
        authorization_config = {
          access_point_id = module.efs.access_points.ray_results.id
          iam             = "ENABLED"
        }
      }
    }
  }
  tags = local.tags
}


################################################################################
# Shared storage - EFS
################################################################################


module "efs" {
  source = "terraform-aws-modules/efs/aws"

  # File system
  name           = "distributed-storage-shared"
  creation_token = "distributed-storage-shared"
  encrypted      = true
  attach_policy  = false

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Mount targets / security group
  mount_targets = {
    (local.azs[0]) = {
      subnet_id = module.vpc.private_subnets[0]
    }
  }

  # Access point
  access_points = {
    ray_results = {
      name = "ray_results"
      posix_user = {
        uid = 1000
        gid = 100
      }
      root_directory = {
        path = "/ray_results"

        creation_info = {
          owner_uid   = 1000
          owner_gid   = 100
          permissions = "755"
        }
      }

      tags = local.tags
    }
  }
  security_group_description = "EFS distributed training security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }

  tags = local.tags
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
            "aws:SourceArn" : "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
  ]

  tags = local.tags
}
