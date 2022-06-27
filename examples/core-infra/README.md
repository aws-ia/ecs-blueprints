# Amazon ECS Demo with fullstack app / Core Infrastructure / Terraform sample

## Table of content

   * [Folder overview](#folder-overview)
   * [General information](#general-information)
   * [Infrastructure](#infrastructure)
      * [Prerequisites](#prerequisites)
      * [Usage](#usage)
   * [Outputs](#outputs)
   * [Cleanup](#cleanup)
   * [Security](#security)
   * [License](#license)

## Folder overview

This folder contains Terraform code to deploy the core infrastrcture of a containerized solution that is intended to be used to run a demo.

## General information

This folder contains the Terraform code to deploy a core Infratructure for a ECS workload.

## Infrastructure

The AWS resources created by the script are detailed bellow:

- Networking
    - 1 VPC
    - 1 Internet Gateway
    - 1 NAT gateway (and 1 EIP)
    - 2 Routing tables (and needed routes)
    - 6 Subnets
        - 2 public subnets
        - 2 private subnets for the client side
        - 2 private subnets for the server side
- ECS
    - 1 ECS Cluster  

## Prerequisites
There are general steps that you must follow in order to launch the infrastructure resources.

Before launching the solution please follow the next steps:

1) Install Terraform, use Terraform v0.13 or above. You can visit [this](https://releases.hashicorp.com/terraform/) Terraform official webpage to download it.
2) Configure the AWS credentials into your machine (~/.aws/credentials). You need to use the following format:

```shell
    [AWS_PROFILE_NAME]
    aws_access_key_id = Replace_with_the_correct_access_Key
    aws_secret_access_key = Replace_with_the_correct_secret_Key
```

3) Generate a GitHub token. You can follow [this](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) steps to generate it.

## Usage

**1.** Fork this repository and create the GitHub token granting access to this new repository in your account.

**2.** Clone that recently forked repository from your account (not the one from the aws-sample organization) and change the directory to the appropriate one as shown below:

```bash
cd examples/core_infra/
```

**3.** Run Terraform init to download the providers and install the modules

```shell
terraform init
```
**4.** Complete the `terraform.tfvars` file with your custom values and then run the terraform plan command specifying the variables in the provided terraform.tfvars file:

```shell
terraform plan -var-file="terraform.tfvars"
```

You can use the `terraform.tfvars.example` file for guidance.

**5.** Review the terraform plan output, take a look at the changes that terraform will execute, and then apply them:

```shell
terraform apply -var-file="terraform.tfvars"
```

## Outputs

After the execution of the Terraform code you will get an output with needed IDs and values needed as input for the nexts Terraform applies (values to be used in the tfvars).

## Cleanup

Run the following command if you want to delete all the resources created before:

```shell
terraform destroy -var-file="terraform.tfvars"
```

---

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
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | The ID of the ECS cluster |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
