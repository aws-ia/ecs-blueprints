# AWS CodeDeploy

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.72.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.72.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_codedeploy_app.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app) | resource |
| [aws_codedeploy_deployment_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_listener"></a> [alb\_listener](#input\_alb\_listener) | The ARN of the ALB listener for production | `string` | n/a | yes |
| <a name="input_codedeploy_role"></a> [codedeploy\_role](#input\_codedeploy\_role) | The role to be assumed by CodeDeploy | `string` | n/a | yes |
| <a name="input_ecs_cluster"></a> [ecs\_cluster](#input\_ecs\_cluster) | The name of the ECS cluster where to deploy | `string` | n/a | yes |
| <a name="input_ecs_service"></a> [ecs\_service](#input\_ecs\_service) | The name of the ECS service to deploy | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name of the CodeDeploy application | `string` | n/a | yes |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | The ARN of the SNS topic where to deliver notifications | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags | `map(string)` | `{}` | no |
| <a name="input_tg_blue"></a> [tg\_blue](#input\_tg\_blue) | The Target group name for the Blue part | `string` | n/a | yes |
| <a name="input_tg_green"></a> [tg\_green](#input\_tg\_green) | The Target group name for the Green part | `string` | n/a | yes |
| <a name="input_trigger_name"></a> [trigger\_name](#input\_trigger\_name) | The name of the notification trigger | `string` | `"CodeDeploy_notification"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_arn"></a> [application\_arn](#output\_application\_arn) | The application ARN for CodeDeploy |
| <a name="output_application_name"></a> [application\_name](#output\_application\_name) | The application name for CodeDeploy |
| <a name="output_deployment_group_arn"></a> [deployment\_group\_arn](#output\_deployment\_group\_arn) | The deployment group ARN for CodeDeploy |
| <a name="output_deployment_group_name"></a> [deployment\_group\_name](#output\_deployment\_group\_name) | The deployment group name for CodeDeploy |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
