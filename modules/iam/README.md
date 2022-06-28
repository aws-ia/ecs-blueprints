# AWS IAM

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
| [aws_iam_policy.devops](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.codedeploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.devops](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.codedeploy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.devops](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.devops](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_code_build_projects"></a> [code\_build\_projects](#input\_code\_build\_projects) | The Code Build projects to which grant IAM access | `list(string)` | <pre>[<br>  "*"<br>]</pre> | no |
| <a name="input_code_deploy_resources"></a> [code\_deploy\_resources](#input\_code\_deploy\_resources) | The Code Deploy applications and deployment groups to which grant IAM access | `list(string)` | <pre>[<br>  "*"<br>]</pre> | no |
| <a name="input_create_codedeploy_role"></a> [create\_codedeploy\_role](#input\_create\_codedeploy\_role) | Set this variable to true if you want to create a role for AWS CodeDeploy | `bool` | `false` | no |
| <a name="input_create_devops_role"></a> [create\_devops\_role](#input\_create\_devops\_role) | Set this variable to true if you want to create a role for AWS DevOps Tools | `bool` | `false` | no |
| <a name="input_ecr_repositories"></a> [ecr\_repositories](#input\_ecr\_repositories) | The ECR repositories to which grant IAM access | `list(string)` | <pre>[<br>  "*"<br>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | The name for the Role | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_codedeploy_role_arn"></a> [codedeploy\_role\_arn](#output\_codedeploy\_role\_arn) | The ARN of the CodeDeploy IAM role |
| <a name="output_codedeploy_role_name"></a> [codedeploy\_role\_name](#output\_codedeploy\_role\_name) | The name of the IAM role |
| <a name="output_devops_role_arn"></a> [devops\_role\_arn](#output\_devops\_role\_arn) | The ARN of the IAM role |
| <a name="output_devops_role_name"></a> [devops\_role\_name](#output\_devops\_role\_name) | The name of the IAM role |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
