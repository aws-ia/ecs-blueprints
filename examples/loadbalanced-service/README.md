# Blueprint: loadbalanced-service

This blueprint provisions an ECS Fargate Service that can be accessed externally.

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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|


## Outputs

| Name | Description |
|------|-------------|

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
