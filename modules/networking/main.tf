# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*==================================================
      AWS Networking for the whole solution
===================================================*/

# ------- VPC Creation -------
resource "aws_vpc" "aws_vpc" {
  cidr_block           = var.cidr[0]
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "vpc_${var.name}"
  }
}

# ------- Get Region Available Zones -------
data "aws_availability_zones" "az_availables" {
  state = "available"
}

# ------- Subnets Creation -------

# ------- Public Subnets -------
resource "aws_subnet" "public_subnets" {
  count                   = 2
  availability_zone       = data.aws_availability_zones.az_availables.names[count.index]
  vpc_id                  = aws_vpc.aws_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.aws_vpc.cidr_block, 7, count.index + 1)
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_${count.index}_${var.name}"
  }
}

# ------- Private Subnets -------
resource "aws_subnet" "private_subnets_client" {
  count             = 2
  availability_zone = data.aws_availability_zones.az_availables.names[count.index]
  vpc_id            = aws_vpc.aws_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.aws_vpc.cidr_block, 7, count.index + 3)
  tags = {
    Name = "private_subnet_client_${count.index}_${var.name}"
  }
}

resource "aws_subnet" "private_subnets_server" {
  count             = 2
  availability_zone = data.aws_availability_zones.az_availables.names[count.index]
  vpc_id            = aws_vpc.aws_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.aws_vpc.cidr_block, 7, count.index + 5)
  tags = {
    Name = "private_subnet_server_${count.index}_${var.name}"
  }
}

# ------- Internet Gateway -------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aws_vpc.id
  tags = {
    Name = "igw_${var.name}"
  }
}

# ------- Create Default Route Public Table -------
resource "aws_default_route_table" "rt_public" {
  default_route_table_id = aws_vpc.aws_vpc.default_route_table_id

  # ------- Internet Route -------
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt_${var.name}"
  }
}

# ------- Create EIP -------
resource "aws_eip" "eip" {
  vpc = true
  tags = {
    Name = "eip-${var.name}"
  }
}

# ------- Attach EIP to Nat Gateway -------
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "nat_${var.name}"
  }
}

# ------- Create Private Route Private Table -------
resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.aws_vpc.id

  # ------- Internet Route -------
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "private_rt_${var.name}"
  }
}

# ------- Private Subnets Association -------
resource "aws_route_table_association" "rt_assoc_priv_subnets_client" {
  count          = 2
  subnet_id      = aws_subnet.private_subnets_client[count.index].id
  route_table_id = aws_route_table.rt_private.id
}

resource "aws_route_table_association" "rt_assoc_priv_subnets_server" {
  count          = 2
  subnet_id      = aws_subnet.private_subnets_server[count.index].id
  route_table_id = aws_route_table.rt_private.id
}

# ------- Public Subnets Association -------
resource "aws_route_table_association" "rt_assoc_pub_subnets" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_vpc.aws_vpc.main_route_table_id
}
