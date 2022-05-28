# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "aws_vpc" {
  description = "The ID of the VPC"
  value       = aws_vpc.aws_vpc.id
}

output "public_subnets" {
  description = "A list of public subnets"
  value       = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id]

}
output "private_subnets_client" {
  description = "A list of private subnets for the client app"
  value       = [aws_subnet.private_subnets_client[0].id, aws_subnet.private_subnets_client[1].id]
}

output "private_subnets_server" {
  description = "A list of private subnets for the server app"
  value       = [aws_subnet.private_subnets_server[0].id, aws_subnet.private_subnets_server[1].id]
}
