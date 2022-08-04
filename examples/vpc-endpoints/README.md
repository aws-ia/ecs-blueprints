# VPC Endpoints

**CAUTION:** You will need to keep `enable_nat_gw = true` in `core-infra` [variables.tf](../core-infra/variables.tf) if you intend to pull container images from Public ECR repositories. This is not supported and is currently blocked by this [PR](https://github.com/aws/containers-roadmap/issues/1160).

This solution blueprint creates VPC Endpoints for S3, ECS, ECR(Private Repositories only), Secrets Manager, and Systems Manager, CloudWatch. There are two steps to deploying this blueprint:

* Deploy the [core-infra](../core-infra/README.md). Note if you have already deployed the infra then you can reuse it as well.
  * **NOTE:** If you would like to disable the NAT Gateway, change `enable_nat_gw = true` in `core-infra` [variables.tf](../core-infra/variables.tf). Please ensure that this solution blueprint deploys successfuly prior to disabling the NAT Gateway in `core-infra`.
* Deploy the terraform templates in this repository using `terraform init` and `terraform apply`


VPC Endpoints optimize the network path by avoiding traffic to internet gateways and incurring cost associated with NAT gateways, NAT instances, or maintaining firewalls. VPC Endpoints also provide you with much finer control over how users and applications access AWS services. VPC Endpoints prevent sensitive data from traversing the Internet, which helps you maintain compliance with regulations such as HIPAA, EU/US Privacy Shield, and PCI.

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
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table) | data source |
| [aws_subnet.private_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | n/a | yes |
| <a name="input_core_stack_name"></a> [core\_stack\_name](#input\_core\_stack\_name) | The name of core infrastructure stack that you created using core-infra module | `string` | `"ecs-blueprint-infra"` | no |
| <a name="input_repository_owner"></a> [repository\_owner](#input\_repository\_owner) | The name of the owner of the forked Github repository | `string` | n/a | yes |
| <a name="input_vpc_tag_key"></a> [vpc\_tag\_key](#input\_vpc\_tag\_key) | The tag key of the VPC and subnets | `string` | `"Name"` | no |
| <a name="input_vpc_tag_value"></a> [vpc\_tag\_value](#input\_vpc\_tag\_value) | The tag value of the VPC and subnets | `string` | `""` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
