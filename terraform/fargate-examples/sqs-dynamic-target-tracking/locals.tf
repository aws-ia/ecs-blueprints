locals {

  name   = var.container_name
  container_name = var.container_name
  
  region = var.aws_region
  scaling_policy_name = var.scaling_policy_name
  desired_latency = var.desired_latency
  default_msg_proc_duration = var.default_msg_proc_duration
  number_of_messages = var.number_of_messages
  app_metric_name = var.app_metric_name
  bpi_metric_name = var.bpi_metric_name
  metric_type = var.metric_type
  metric_namespace = var.metric_namespace

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}
