output "lambda_function_message_producer" {
  value       = module.lambda_function_message_producer.lambda_function_arn
  description = "lambda_function_message_producer"
}

output "lambda_function_target_bpi_update" {
  value       = module.lambda_function_target_bpi_update.lambda_function_arn
  description = "lambda_function_target_bpi_update"
}

output "sqs_message_producer_cw_event_rule_arn" {
  value       = aws_cloudwatch_event_rule.sqs_message_producer.arn
  description = "sqs_message_producer_cw_event_rule_arn"
}

output "aws_sns_topic" {
  value       = aws_sns_topic.codestar_notification.arn
  description = "aws_sns_topic"
}

output "ecs_target" {
  value       = aws_appautoscaling_target.ecs_target.resource_id
  description = "ecs_target"
}

output "ecs_target_min" {
  value       = aws_appautoscaling_target.ecs_target.min_capacity
  description = "ecs_target_min"
}

output "ecs_target_max" {
  value       = aws_appautoscaling_target.ecs_target.max_capacity
  description = "ecs_target_max"
}

output "ecs_sqs_app_scaling_policy_arn" {
  value       = aws_appautoscaling_policy.ecs_sqs_app_scaling_policy.arn
  description = "ecs_sqs_app_scaling_policy_arn"
}
