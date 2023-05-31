# Core Infrastructure
This folder contains the Terraform code to deploy the core infratructure for an ECS EC2 based workload. The AWS resources created by the script are:
* Networking
  * VPC
    * 3 public subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of public subnets as AZs.
    * 3 private subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of private subnets as AZs.
    * 1 NAT Gateway
    * 1 Internet Gateway
    * Associated Route Tables
* 1 ECS Cluster with Auto Scaling group capacity provider and AWS CloudWatch Container Insights enabled.
* Task execution IAM role
* CloudWatch log groups
* CloudMap service discovery namespace `default`

## Getting Started
Make sure you have all the [prerequisites](../../README.md) for your laptop.

Fork this repository and [create the GitHub token granting access](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to this new repository in your account. Store this secret in AWS secrets manager using the aws cli.
```shell
aws secretsmanager create-secret --name ecs-github-token --secret-string "<github-token-created-above>"
```
Note you should create the secret in an AWS region where you plan to deploy the various examples. You can set the default region by exporting the environment variable `export AWS_DEFAULT_REGION=<default-region>` or in `~/.aws/config`.

## Usage
* Clone the forked repository from your account (not the one from the aws-ia organization) and change the directory to the appropriate one as shown below:
```bash
cd ec2-examples/core-infra/
```
* Run Terraform init to download the providers and install the modules
```shell
terraform init
```
* Copy the `terraform.tfvars.example` to `terraform.tfvars` and change as needed especially note the region.
```shell
cp terraform.tfvars.example terraform.tfvars
```
* Review the terraform plan output, take a look at the changes that terraform will execute, and then apply them:
```shell
terraform plan
terraform apply --auto-approve
```
## Outputs
After the execution of the Terraform code you will get an output with needed IDs and values needed as input for the nexts Terraform applies. You can use this infrastructure to run other example blueprints, all you need is the `cluster_name`.

## Cleanup
Run the following command if you want to delete all the resources created before. If you have created other blueprints and they use these infrastructure then destroy those blueprint resources first.
```shell
terraform destroy
```


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.55 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.55 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_autoscaling"></a> [autoscaling](#module\_autoscaling) | terraform-aws-modules/autoscaling/aws | ~> 6.5 |
| <a name="module_autoscaling_sg"></a> [autoscaling\_sg](#module\_autoscaling\_sg) | terraform-aws-modules/security-group/aws | ~> 4.0 |
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | ~> 5.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_service_discovery_private_dns_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ssm_parameter.ecs_optimized_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN that identifies the cluster |
| <a name="output_cluster_autoscaling_capacity_providers"></a> [cluster\_autoscaling\_capacity\_providers](#output\_cluster\_autoscaling\_capacity\_providers) | Map of capacity providers created and their attributes |
| <a name="output_cluster_capacity_providers"></a> [cluster\_capacity\_providers](#output\_cluster\_capacity\_providers) | Map of cluster capacity providers attributes |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ID that identifies the cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name that identifies the cluster |
| <a name="output_ecs_task_execution_role_arn"></a> [ecs\_task\_execution\_role\_arn](#output\_ecs\_task\_execution\_role\_arn) | The ARN of the task execution role |
| <a name="output_ecs_task_execution_role_name"></a> [ecs\_task\_execution\_role\_name](#output\_ecs\_task\_execution\_role\_name) | The ARN of the task execution role |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | A list of private subnets for the client app |
| <a name="output_private_subnets_cidr_blocks"></a> [private\_subnets\_cidr\_blocks](#output\_private\_subnets\_cidr\_blocks) | A list of private subnets CIDRs |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | A list of public subnets |
| <a name="output_service_discovery_namespaces"></a> [service\_discovery\_namespaces](#output\_service\_discovery\_namespaces) | Service discovery namespaces already available |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
