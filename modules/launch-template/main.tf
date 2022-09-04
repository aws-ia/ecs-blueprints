data "aws_region" "current" {}

################################################################################
# ECS Instance Role
################################################################################
resource "aws_iam_role" "ecs-instance-role" {
    name                = "ecs-instance-role"
    path                = "/"
    assume_role_policy  = "${data.aws_iam_policy_document.ecs-instance-policy.json}"
}

data "aws_iam_policy_document" "ecs-instance-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
    role       = aws_iam_role.ecs-instance-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
    name = "ecs-instance-profile"
    path = "/"
    role = aws_iam_role.ecs-instance-role.name
}
################################################################################
# Launch Template
################################################################################

data "aws_ami" "ecs_optimized" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.20220831-x86_64-ebs"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_launch_template" "ecs_blueprint_lt" {
    name = var.name
    #Block Device Size
    block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.volume_size
    }
  }

#Replace ECS Optimized AMI
image_id = data.aws_ami.ecs_optimized.image_id

#Instance Shutdown Behaviour, Replace as per the use case
instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior

#Choose Instance Type As Per Use Case
instance_type = var.instance_type

#Choose your security group as per the use case
vpc_security_group_ids = [var.vpc_security_group_ids]

#Choose tags as per the use case
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs_blueprint_container_instance"
    }
  }

#Specify the ecsInstanceRole for RegisterContainerInstance

iam_instance_profile {
    name = aws_iam_instance_profile.ecs-instance-profile.name
  }

#Specify the user-data and pass the cluster details 
user_data = filebase64("${path.module}/example.sh")
}