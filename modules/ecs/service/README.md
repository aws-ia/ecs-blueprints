# Module: ecs/service

This module provides an ECS Service.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecs_service.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the container | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The port that the container will listen request | `number` | n/a | yes |
| <a name="input_deployment_controller"></a> [deployment\_controller](#input\_deployment\_controller) | Specifies which deployment controller to use for the service. | `string` | `"ECS"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Maximum percentage of task able to be deployed | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | The minimum number of tasks, specified as a percentage of the Amazon ECS service's DesiredCount value, that must continue to run and remain healthy during a deployment. | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | The desired number of instantiations of the task definition to keep running on the service. | `number` | `1` | no |
| <a name="input_ecs_cluster_id"></a> [ecs\_cluster\_id](#input\_ecs\_cluster\_id) | The ECS cluster ID in which the resources will be created | `string` | n/a | yes |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Number of seconds for the task health check | `number` | `0` | no |
| <a name="input_name"></a> [name](#input\_name) | The name for the ecs service | `string` | n/a | yes |
| <a name="input_security_group"></a> [security\_group](#input\_security\_group) | The security groups to associate with the service. | `string` | `""` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | The subnets to associate with the service. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags | `map(string)` | n/a | yes |
| <a name="input_target_group"></a> [target\_group](#input\_target\_group) | The ARN of the AWS Target Group to put the ECS task | `string` | `""` | no |
| <a name="input_task_definition"></a> [task\_definition](#input\_task\_definition) | The ARN of the Task Definition to use to deploy the tasks | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_arn"></a> [service\_arn](#output\_service\_arn) | The ECS Service ARN |
