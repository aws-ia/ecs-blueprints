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
| [aws_codedeploy_app.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app) | resource |
| [aws_codedeploy_deployment_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_listener"></a> [alb\_listener](#input\_alb\_listener) | The ARN of the ALB listener for production | `string` | n/a | yes |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Set this variable to true if you want to create a role for AWS CodeDeploy | `bool` | `false` | no |
| <a name="input_ecs_cluster"></a> [ecs\_cluster](#input\_ecs\_cluster) | The name of the ECS cluster where to deploy | `string` | n/a | yes |
| <a name="input_ecs_service"></a> [ecs\_service](#input\_ecs\_service) | The name of the ECS service to deploy | `string` | n/a | yes |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | The name for the Role | `string` | n/a | yes |
| <a name="input_iam_role_use_name_prefix"></a> [iam\_role\_use\_name\_prefix](#input\_iam\_role\_use\_name\_prefix) | Determines whether the IAM role name (`iam_role_name`) is used as a prefix | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the CodeDeploy application | `string` | n/a | yes |
| <a name="input_service_role"></a> [service\_role](#input\_service\_role) | Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account | `string` | n/a | yes |
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
| <a name="output_codedeploy_role_arn"></a> [codedeploy\_role\_arn](#output\_codedeploy\_role\_arn) | The ARN of the IAM role |
| <a name="output_codedeploy_role_name"></a> [codedeploy\_role\_name](#output\_codedeploy\_role\_name) | The name of the IAM role |
| <a name="output_deployment_group_arn"></a> [deployment\_group\_arn](#output\_deployment\_group\_arn) | The deployment group ARN for CodeDeploy |
| <a name="output_deployment_group_name"></a> [deployment\_group\_name](#output\_deployment\_group\_name) | The deployment group name for CodeDeploy |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
