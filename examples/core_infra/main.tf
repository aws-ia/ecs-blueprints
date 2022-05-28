# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

/*===========================
          Root file
============================*/

# ------- Providers -------
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# ------- Networking -------
module "networking" {
  source = "../../modules/networking"
  cidr   = ["10.120.0.0/16"]
  name   = var.environment_name
}

# ------- Creating ECS Cluster -------
module "ecs_cluster" {
  source = "../../modules/ecs/cluster"
  name   = var.environment_name
}
