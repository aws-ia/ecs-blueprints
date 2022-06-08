# Module: ecs/task-definition

This module provides an ECS Task Definition.

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
| [aws_ecs_task_definition.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudwatch_log_group"></a> [cloudwatch\_log\_group](#input\_cloudwatch\_log\_group) | cloudwatch log group | `string` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Container specified in the Task definition | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The port that the container will use to listen to requests | `number` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | The number of cpu units used by the task. | `number` | `256` | no |
| <a name="input_execution_role"></a> [execution\_role](#input\_execution\_role) | The task execution role arn | `string` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | The container image | `string` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | The MEMORY value to assign to the container, read AWS documentation to available values | `number` | `512` | no |
| <a name="input_name"></a> [name](#input\_name) | The name for Task Definition | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which the resources will be deployed | `string` | n/a | yes |
| <a name="input_task_role"></a> [task\_role](#input\_task\_role) | The IAM role that the ECS task will use to call other AWS services | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | The ARN of the task definition |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | The family name of the task definition |
