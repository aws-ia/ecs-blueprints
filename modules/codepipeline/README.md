# AWS CodePipeline

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
| [aws_codepipeline.aws_codepipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | resource |
| [aws_codestarnotifications_notification_rule.codepipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarnotifications_notification_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_branch"></a> [branch](#input\_branch) | Github branch used to trigger the CodePipeline | `string` | n/a | yes |
| <a name="input_client_deploy_configuration"></a> [client\_deploy\_configuration](#input\_client\_deploy\_configuration) | The configuration to use for the client deployment | `map(string)` | `{}` | no |
| <a name="input_codebuild_project_client"></a> [codebuild\_project\_client](#input\_codebuild\_project\_client) | Client's CodeBuild project name | `string` | n/a | yes |
| <a name="input_codebuild_project_server"></a> [codebuild\_project\_server](#input\_codebuild\_project\_server) | Server's CodeBuild project name | `string` | n/a | yes |
| <a name="input_deploy_provider"></a> [deploy\_provider](#input\_deploy\_provider) | The provider to use for deployment | `string` | `"ECS"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | Personal access token from Github | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The CodePipeline pipeline name | `string` | n/a | yes |
| <a name="input_pipe_role"></a> [pipe\_role](#input\_pipe\_role) | The role assumed by CodePipeline | `string` | n/a | yes |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | Github repository's name | `string` | n/a | yes |
| <a name="input_repo_owner"></a> [repo\_owner](#input\_repo\_owner) | The username of the Github repository owner | `string` | n/a | yes |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | S3 bucket used for the artifact store | `string` | n/a | yes |
| <a name="input_server_deploy_configuration"></a> [server\_deploy\_configuration](#input\_server\_deploy\_configuration) | The configuration to use for the server deployment | `map(string)` | `{}` | no |
| <a name="input_sns_topic"></a> [sns\_topic](#input\_sns\_topic) | The ARN of the SNS topic to use for pipline notifications | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
