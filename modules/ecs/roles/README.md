# Module: ecs/roles

This module provides IAM Roles (ECS Execution and ECS Task) needed for ECS.

Pass in the IAM policy that you want the task role to assume.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
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
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | The name | `string` | n/a | yes |
| <a name="input_task_role_policy"></a> [task\_role\_policy](#input\_task\_role\_policy) | The task's role policy | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_execution_role"></a> [execution\_role](#output\_execution\_role) | The task execution role arn |
| <a name="output_task_role"></a> [task\_role](#output\_task\_role) | The task role arn |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
