# AWS CodeBuild

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
| [aws_codebuild_project.aws_codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buildspec_path"></a> [buildspec\_path](#input\_buildspec\_path) | Path to for the Buildspec file | `string` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Container specified in the Task definition | `string` | n/a | yes |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | The name of Dynamodb table used by the server application | `string` | `""` | no |
| <a name="input_ecr_repo_url"></a> [ecr\_repo\_url](#input\_ecr\_repo\_url) | AWS ECR repository URL where docker images are being stored | `string` | n/a | yes |
| <a name="input_ecs_role"></a> [ecs\_role](#input\_ecs\_role) | The name of the ECS Task Excecution role to specify in the Task Definition | `string` | n/a | yes |
| <a name="input_ecs_task_role"></a> [ecs\_task\_role](#input\_ecs\_task\_role) | The name of the ECS Task role to specify in the Task Definition | `string` | `"null"` | no |
| <a name="input_folder_path"></a> [folder\_path](#input\_folder\_path) | Folder path to use to build the docker images/containers | `string` | n/a | yes |
| <a name="input_iam_role"></a> [iam\_role](#input\_iam\_role) | IAM role to attach to CodeBuild | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | CodeBuild Project name | `string` | n/a | yes |
| <a name="input_server_alb_url"></a> [server\_alb\_url](#input\_server\_alb\_url) | The server ALB DNS. Used to build the code for the frontend layer | `string` | `""` | no |
| <a name="input_service_port"></a> [service\_port](#input\_service\_port) | The number of the port used by the ECS Service | `number` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags | `map(string)` | `{}` | no |
| <a name="input_task_definition_family"></a> [task\_definition\_family](#input\_task\_definition\_family) | The family name of the Task definition | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_arn"></a> [project\_arn](#output\_project\_arn) | The ARN of the CodeBuild project |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the CodeBuild project |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
