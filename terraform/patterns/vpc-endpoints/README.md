# VPC Endpoints

This self-contained blueprint runs ECS tasks in private subnets with **no NAT gateway and
no internet gateway** — all AWS API traffic flows over VPC endpoints. A single
`terraform apply` creates its own VPC, the endpoints, an ECS cluster, and the demo
service; `terraform destroy` removes everything.

Because `public.ecr.aws` is not reachable through the ECR interface endpoints (see this
[roadmap issue](https://github.com/aws/containers-roadmap/issues/1160)), the blueprint
provisions an **ECR pull-through cache rule**: the task pulls its image from a private ECR
repository over the `ecr.dkr`/`ecr.api`/S3 endpoints, and ECR transparently fetches and
caches the upstream public image on the first pull. This is what lets the pattern run with
no internet egress at all.

This blueprint creates VPC Endpoints for S3, ECS, ECR (private repositories), SQS, Secrets
Manager, Systems Manager, and CloudWatch Logs.


VPC Endpoints optimize the network path by avoiding traffic to internet gateways and incurring cost associated with NAT gateways, NAT instances, or maintaining firewalls. VPC Endpoints also provide you with much finer control over how users and applications access AWS services. VPC Endpoints prevent sensitive data from traversing the Internet, which helps you maintain compliance with regulations such as HIPAA, EU/US Privacy Shield, and PCI.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.56 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.56 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 7.5.0 |
| <a name="module_ecs_service"></a> [ecs\_service](#module\_ecs\_service) | terraform-aws-modules/ecs/aws//modules/service | 7.5.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.6.1 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | 6.6.1 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_pull_through_cache_rule.public_ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_ecr_repository.cached_demo_image](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region in which to deploy the example. | `string` | `"us-west-2"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for resources. Change this to deploy another copy in the same account and Region. | `string` | `"ecsdemo-vpc-endpoints"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cached_image"></a> [cached\_image](#output\_cached\_image) | Private ECR pull-through cache image URI the service pulls through the VPC endpoints |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster |
| <a name="output_vpc_endpoints"></a> [vpc\_endpoints](#output\_vpc\_endpoints) | Map of VPC endpoint names to endpoint IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC (no internet gateway or NAT gateway) |
<!-- END_TF_DOCS -->

## Cost

This example creates billable AWS resources. Review `terraform plan`, use a sandbox account, and avoid leaving the stack deployed when it is not in use. NAT gateways, load balancers, databases, and accelerated instances are common cost drivers where present.

## Quotas

Confirm that the target Region has sufficient ECS task, elastic network interface, load balancer, and any workload-specific service quotas before deployment. EC2 examples also require available capacity for the selected instance types.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review `terraform plan` before applying. After deployment, use the functional check described above and inspect ECS service events and CloudWatch Logs for task failures.

## Cleanup

Run `terraform destroy` from this example directory. Remove retained data or separately created secrets only after confirming they are no longer needed.
