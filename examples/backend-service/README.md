# Blueprint: backend-service

This blueprint provisions an ECS Fargate Service that can't be accessed externally, but only from other services within your application.

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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ../../modules/ecs/cluster | n/a |
| <a name="module_ecr"></a> [ecr](#module\_ecr) | ../../modules/ecr | n/a |
| <a name="module_roles"></a> [roles](#module\_roles) | ../../modules/ecs/roles | n/a |
| <a name="module_service"></a> [service](#module\_service) | ../../modules/ecs/service | n/a |
| <a name="module_task_definition"></a> [task\_definition](#module\_task\_definition) | ../../modules/ecs/task-definition | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | >= 1.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_security_group.allow_all_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.allow_all_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_iam_policy_document.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cpu"></a> [cpu](#input\_cpu) | The number of cpu units used by the task. | `number` | `256` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | The desired number of instantiations of the task definition to keep running on the service. | `number` | `1` | no |
| <a name="input_image"></a> [image](#input\_image) | the container image | `string` | n/a | yes |
| <a name="input_logs_retention_in_days"></a> [logs\_retention\_in\_days](#input\_logs\_retention\_in\_days) | how many days are retained for | `number` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | The amount (in MiB) of memory used by the task. | `number` | `512` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | A namespace for the app.  This gets applied to things like the ECS Cluster and Service name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | aws region | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service"></a> [service](#output\_service) | The ECS Service ARN |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
