provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name                       = "ecs-demo-fsdp"
  region                     = "us-west-2"
  instance_type_workers      = "g5.12xlarge"
  instance_type_head         = "g5.12xlarge"
  ray_head_container_image   = "ecs-blueprint-fsdp-ray:2.38.0-py310-gpu"
  ray_worker_container_image = "ecs-blueprint-fsdp-ray:2.38.0-py310-gpu"

  user_data_head = <<-EOT
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
        "namespace": "EcsBlueprints/DistributedTrainingFSDP",
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

# Keep the ECS agent stopped while the container image is built locally so the
# cluster cannot place tasks on this instance before the image exists.
systemctl stop ecs

cat << 'EOF' > Dockerfile
FROM docker.io/rayproject/ray:2.38.0-py310-gpu
RUN pip install datasets evaluate "transformers==4.29.2" "torch>=1.12.0" "lightning==2.0.2"
EOF

docker build -t ecs-blueprint-fsdp-ray:2.38.0-py310-gpu .

# --no-block: ecs.service is ordered After=cloud-final.service, and this script
# runs inside cloud-final, so a blocking start would deadlock. The queued start
# job runs as soon as user data (cloud-final) finishes.
systemctl start ecs --no-block

  EOT

  user_data_workers = <<-EOT
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
        "namespace": "EcsBlueprints/DistributedTrainingFSDP",
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

# Keep the ECS agent stopped while the container image is built locally so the
# cluster cannot place tasks on this instance before the image exists.
systemctl stop ecs

cat << 'EOF' > Dockerfile
FROM docker.io/rayproject/ray:2.38.0-py310-gpu
RUN pip install datasets evaluate "transformers==4.29.2" "torch>=1.12.0" "lightning==2.0.2"
EOF

docker build -t ecs-blueprint-fsdp-ray:2.38.0-py310-gpu .

# --no-block: ecs.service is ordered After=cloud-final.service, and this script
# runs inside cloud-final, so a blocking start would deadlock. The queued start
# job runs as soon as user data (cloud-final) finishes.
systemctl start ecs --no-block

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
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = local.name
  # Capacity provider - autoscaling groups
  # Capacity provider names are unique per account/region, so they are
  # prefixed with fsdp to avoid colliding with distributed-ml-training.
  capacity_providers = {
    fsdp_training_head = {
      auto_scaling_group_provider = {
        auto_scaling_group_arn = module.autoscaling_head.autoscaling_group_arn

        managed_scaling = {
          maximum_scaling_step_size = 1
          minimum_scaling_step_size = 1
          status                    = "ENABLED"
          target_capacity           = 60
        }
      }
    },
    fsdp_training_workers = {
      auto_scaling_group_provider = {
        auto_scaling_group_arn = module.autoscaling_workers.autoscaling_group_arn
        managed_scaling = {
          maximum_scaling_step_size = 1
          minimum_scaling_step_size = 1
          status                    = "ENABLED"
          target_capacity           = 60
        }
      }
    },
  }

  # Shared task execution role
  create_task_exec_iam_role = false
  tags                      = local.tags
}

resource "aws_service_discovery_service" "this" {
  # Unique per example: other blueprints (distributed-ml-training,
  # distributed-inference-ray-serve) register their own head service in the
  # shared default.core-infra.local namespace.
  name = "head-fsdp"
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
  name     = "${local.name}-ml-training"
  strategy = "cluster"
}

module "autoscaling_head" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.2.1"

  name = "${local.name}-head"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_gpu_optimized_ami.value)["image_id"]
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
        encrypted             = true
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

module "autoscaling_workers" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.2.1"

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
        encrypted             = true
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
      description = "Allow all to internet"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}


module "ecs_service_head" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  disable_v7_default_name_description = true
  name                                = "fsdp_training_head_service"
  desired_count                       = 1
  cluster_arn                         = module.ecs_cluster.arn
  enable_autoscaling                  = false
  memory                              = 184320
  cpu                                 = 10240

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.capacity_providers["fsdp_training_head"].name # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  task_exec_iam_role_arn     = aws_iam_role.task_execution_role.arn
  tasks_iam_role_name        = "taskRole"
  tasks_iam_role_description = "Task role for ${local.name}"
  tasks_iam_role_statements = [
    {
      effect  = "Allow",
      actions = ["s3:*"]
      resources = [
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.results.bucket}/*"
      ]
    }
  ]
  create_task_exec_iam_role          = false
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 0
  container_definitions = {

    ray_head = {
      readonlyRootFilesystem = false
      image                  = local.ray_head_container_image
      user                   = 1000
      cpu                    = 10240
      memory                 = 184320
      memoryReservation      = 184320
      command                = ["/bin/bash", "-lc", "--", "ulimit -n 65536; ray start --head --dashboard-host=0.0.0.0 --metrics-export-port=8080 --num-cpus=10 --num-gpus=4 --memory=193273528320 --block"]
      linuxParameters = {
        sharedMemorySize   = 20480
        initProcessEnabled = true
      }
      resourceRequirements = [{
        type  = "GPU"
        value = 4
      }]
      mountPoints = [{
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  volume = {
    "tmp" = {
      docker_volume_configuration = {
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
  security_group_ingress_rules = {
    ingress_private_ips = {
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.core_infra.cidr_block
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  tags = local.tags
}


module "ecs_service_workers" {
  source                              = "terraform-aws-modules/ecs/aws//modules/service"
  version                             = "7.5.0"
  disable_v7_default_name_description = true
  deployment_minimum_healthy_percent  = 0
  name                                = "fsdp_training_worker_service"
  desired_count                       = 1
  cluster_arn                         = module.ecs_cluster.arn
  enable_autoscaling                  = false
  memory                              = 184320
  cpu                                 = 10240
  # Task Definition

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.capacity_providers["fsdp_training_workers"].name # needs to match name of capacity provider
      weight            = 1
      base              = 1
    }
  }

  task_exec_iam_role_arn     = aws_iam_role.task_execution_role.arn
  tasks_iam_role_name        = "taskRole"
  tasks_iam_role_description = "Task role for ${local.name}"
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
      readonlyRootFilesystem = false
      image                  = local.ray_worker_container_image
      user                   = 1000
      cpu                    = 10240
      memory                 = 184320
      memoryReservation      = 184320
      command                = ["/bin/bash", "-lc", "--", "ulimit -n 65536; ray start --block --num-cpus=10 --num-gpus=4 --memory=193273528320 --address=${aws_service_discovery_service.this.name}.${data.aws_service_discovery_dns_namespace.core_infra.name}:6379 --metrics-export-port=8080"]
      linuxParameters = {
        sharedMemorySize = 10240
      }
      resourceRequirements = [{
        type  = "GPU"
        value = 4
      }]
      mountPoints = [{
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }
  }
  volume = {
    "tmp" = {
      docker_volume_configuration = {
        scope         = "shared",
        driver        = "local",
        autoprovision = true
      }
    }
  }

  network_mode = "awsvpc"
  subnet_ids   = data.aws_subnets.private.ids
  security_group_ingress_rules = {
    ingress_private_ips = {
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.core_infra.cidr_block
    }
  }
  security_group_egress_rules = {
    egress_all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  tags = local.tags
}

resource "random_id" "bucket_name" {
  byte_length = 8
}

resource "aws_s3_bucket" "results" {
  bucket = "dt-results-${random_id.bucket_name.hex}"
  tags   = local.tags
  # force_destroy is intentional for this demo so `terraform destroy` removes
  # the bucket even when it still contains training results. Remove it if you
  # need to retain outputs.
  force_destroy = true
}

# Add public access block
resource "aws_s3_bucket_public_access_block" "results_access_block" {
  bucket = aws_s3_bucket.results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explicit SSE-S3 encryption at rest for training results
resource "aws_s3_bucket_server_side_encryption_configuration" "results" {
  bucket = aws_s3_bucket.results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "task_execution_role" {
  # Unique per example: distributed-ml-training creates
  # "distributed_training_task_execution_role" in the same account.
  name = "fsdp_training_task_execution_role"

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
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# Supporting Resources
################################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux

data "aws_ssm_parameter" "ecs_gpu_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended"
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

resource "null_resource" "wait_for_instance" {
  depends_on = [
    module.autoscaling_head
  ]
  # Stable triggers: re-run only when the ASGs or their launch template
  # versions change, instead of on every apply (timestamp()).
  triggers = {
    head_asg_name                  = module.autoscaling_head.autoscaling_group_name
    head_launch_template_version   = module.autoscaling_head.launch_template_latest_version
    worker_asg_name                = module.autoscaling_workers.autoscaling_group_name
    worker_launch_template_version = module.autoscaling_workers.launch_template_latest_version
  }
  provisioner "local-exec" {
    command = "${path.module}/check_instance_state.sh ${local.name}"
    environment = {
      AWS_REGION = local.region
    }
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

  lifecycle {
    postcondition {
      condition     = length(self.ids) >= 2
      error_message = "GPU capacity not available: expected at least 2 running instances tagged Blueprint=${local.name} (head + worker), found ${length(self.ids)}. Check EC2 capacity/quotas for ${local.instance_type_workers} in ${local.region} and re-run apply."
    }
  }
}

resource "aws_cloudwatch_dashboard" "distributed_ml_training_fsdp_dashboard" {
  dashboard_name = "distributed-ml-training-fsdp"

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
              "EcsBlueprints/DistributedTrainingFSDP",
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
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
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
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
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
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
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
                "region" : local.region
              }
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : local.region,
          "title" : "${data.aws_instances.tagged_instances.ids[0]} - GPU memory utilization (MiB)",
          "period" : 60,
          "stat" : "Average"
          "start" : "-PT60M",
          "end" : "P0D"
        }
      },
      {
        "height" : 7,
        "width" : 12,
        "y" : 14,
        "x" : 0,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            [
              "EcsBlueprints/DistributedTrainingFSDP",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[1],
              "name",
              "NVIDIA A10G",
              "index",
              "3",
              "arch",
              "Ampere",
              {
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[1],
              "name",
              "NVIDIA A10G",
              "index",
              "2",
              "arch",
              "Ampere",
              {
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[1],
              "name",
              "NVIDIA A10G",
              "index",
              "0",
              "arch",
              "Ampere",
              {
                "region" : local.region
              }
            ],
            [
              "EcsBlueprints/DistributedTrainingFSDP",
              "nvidia_smi_memory_used",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[1],
              "name",
              "NVIDIA A10G",
              "index",
              "1",
              "arch",
              "Ampere",
              {
                "region" : local.region
              }
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : local.region,
          "title" : "${data.aws_instances.tagged_instances.ids[1]} - GPU memory utilization (MiB)",
          "period" : 60,
          "stat" : "Average",
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
              "EcsBlueprints/DistributedTrainingFSDP",
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
                "region" : local.region
              }
            ],
            [
              "...",
              "2",
              ".",
              ".",
              {
                "region" : local.region
              }
            ],
            [
              "...",
              "3",
              ".",
              ".",
              {
                "region" : local.region
              }
            ],
            [
              "...",
              "1",
              ".",
              ".",
              {
                "region" : local.region
              }
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : local.region,
          "title" : "${data.aws_instances.tagged_instances.ids[0]} - GPU utilization percentage",
          "period" : 60,
          "stat" : "Average",
          "start" : "-PT60M",
          "end" : "P0D"
        }
      },
      {
        "height" : 7,
        "width" : 12,
        "y" : 14,
        "x" : 12,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            [
              "EcsBlueprints/DistributedTrainingFSDP",
              "nvidia_smi_utilization_gpu",
              "InstanceId",
              data.aws_instances.tagged_instances.ids[1],
              "name",
              "NVIDIA A10G",
              "index",
              "3",
              "arch",
              "Ampere"
            ],
            [
              "...",
              "2",
              ".",
              "."
            ],
            [
              "...",
              "1",
              ".",
              "."
            ],
            [
              "...",
              "0",
              ".",
              "."
            ]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : local.region,
          "title" : "${data.aws_instances.tagged_instances.ids[1]} - GPU utilization percentage",
          "period" : 60,
          "stat" : "Average",
          "start" : "-PT60M",
          "end" : "P0D"
        }
      }
    ]
  })
}
