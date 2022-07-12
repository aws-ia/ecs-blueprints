data "aws_vpc" "vpc" {
  filter {
    name = "tag:${var.vpc_tag_key}"
    values = [var.vpc_tag_value]
  }
}

data "aws_subnets" "private_subnets" {

  filter {
    name = "tag:${var.vpc_tag_key}"
    values = ["${var.private_subnets}*"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}

data "aws_subnets" "public_subnets" {

  filter {
    name = "tag:${var.vpc_tag_key}"
    values = ["${var.public_subnets}*"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name
}
