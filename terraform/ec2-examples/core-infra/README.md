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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.55 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.55 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_autoscaling"></a> [autoscaling](#module\_autoscaling) | terraform-aws-modules/autoscaling/aws | ~> 6.5 |
| <a name="module_autoscaling_sg"></a> [autoscaling\_sg](#module\_autoscaling\_sg) | terraform-aws-modules/security-group/aws | ~> 4.0 |
| <a name="module_ecs"></a> [ecs](#module\_ecs) | github.com/clowdhaus/terraform-aws-ecs | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_service_discovery_private_dns_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ecs_optimized_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_asg_name"></a> [asg\_name](#input\_asg\_name) | Name of the AutoScaling Group | `string` | `"ecs_blueprint_asg"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_capcitiy-provider_name"></a> [capcitiy-provider\_name](#input\_capcitiy-provider\_name) | Name of capacity provider | `string` | `"capacity-provide-blue-print"` | no |
| <a name="input_core_stack_name"></a> [core\_stack\_name](#input\_core\_stack\_name) | The name of Core Infrastructure stack, feel free to rename it. Used for cluster and VPC names. | `string` | `"ecs-blueprint-infra"` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Desire Capacity Of AutoScalingGroup | `number` | `1` | no |
| <a name="input_enable_nat_gw"></a> [enable\_nat\_gw](#input\_enable\_nat\_gw) | Provision a NAT Gateway in the VPC | `bool` | `true` | no |
| <a name="input_instance_initiated_shutdown_behavior"></a> [instance\_initiated\_shutdown\_behavior](#input\_instance\_initiated\_shutdown\_behavior) | Shutdown behavioure on instance | `string` | `"terminate"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | ECS Container Instance Instance Type | `string` | `"c6a.2xlarge"` | no |
| <a name="input_launch_name"></a> [launch\_name](#input\_launch\_name) | Name of the Launch Template | `string` | `"ecs-blueprint-launch_template"` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum Size Of AutoScalingGroup | `number` | `4` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum Size Of AutoScalingGroup | `number` | `1` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | List of service discovery namespaces for ECS services. Creates a default namespace | `list(string)` | <pre>[<br>  "default",<br>  "myapp"<br>]</pre> | no |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | n/a | `string` | `30` | no |
| <a name="input_volume_type"></a> [volume\_type](#input\_volume\_type) | Volume type to be used | `string` | `"gp2"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |

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
