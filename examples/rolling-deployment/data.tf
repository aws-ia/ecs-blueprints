data "aws_vpc" "vpc" {
  filter {
    name = "tag:Name"
    values = ["core-infra"]
  }
}

data "aws_subnets" "private_subnets" {

  filter {
    name = "tag:Name"
    values = ["core-infra-private-*"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}

data "aws_subnets" "public_subnets" {

  filter {
    name = "tag:Name"
    values = ["core-infra-public-*"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = "core-infra"
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = "core-infra-execution"
}
