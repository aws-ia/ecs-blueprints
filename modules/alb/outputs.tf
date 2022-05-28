# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "arn_alb" {
  description = "The ARN of the ALB"
  value = (var.create_alb == true
  ? (length(aws_alb.alb) > 0 ? aws_alb.alb[0].arn : "") : "")
}
output "arn_tg" {
  description = "The ARN of the target group"
  value = (var.create_target_group == true
  ? (length(aws_alb_target_group.target_group) > 0 ? aws_alb_target_group.target_group[0].arn : "") : "")
}

output "tg_name" {
  description = "The target group name"
  value = (var.create_target_group == true
  ? (length(aws_alb_target_group.target_group) > 0 ? aws_alb_target_group.target_group[0].name : "") : "")
}

output "arn_listener" {
  description = "The ARN of the load balancer listener"
  value = (var.create_alb == true
  ? (length(aws_alb_listener.http_listener) > 0 ? aws_alb_listener.http_listener[0].arn : "") : "")
}

output "dns_alb" {
  description = "The DNS of the created ALB"
  value = (var.create_alb == true
  ? (length(aws_alb.alb) > 0 ? aws_alb.alb[0].dns_name : "") : "")
}
