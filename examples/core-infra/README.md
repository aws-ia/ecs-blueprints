# Core Infrastructure
This folder contains the Terraform code to deploy the core infratructure for an ECS Fargate workload.

## Table of content
   * [Infrastructure](#infrastructure)
      * [Prerequisites](#prerequisites)
      * [Usage](#usage)
   * [Outputs](#outputs)
   * [Cleanup](#cleanup)
   * [Security](#security)
   * [License](#license)


## Infrastructure

The AWS resources created by the script are detailed bellow:

- Networking
    - 1 VPC
    - 1 Internet Gateway
    - 1 NAT gateway (and 1 EIP)
    - 2 Routing tables (and needed routes)
    - 3 public subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of public subnets as AZs. 
    - 3 private subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of public subnets as AZs.
- ECS
    - 1 ECS Cluster with AWS CloudWatch Container Insights enabled.
- IAM 
    - 1 task-execution-iam-role  

## Prerequisites
There are general steps that you must follow in order to launch the infrastructure resources.

Before launching the solution please follow the next steps:

1) Install Terraform, use Terraform v1.0 or above. You can visit [this](https://releases.hashicorp.com/terraform/) Terraform official webpage to download it.
2) Configure the AWS credentials into your machine (~/.aws/credentials). You need to use the following format:
```shell
    [AWS_PROFILE_NAME]
    aws_access_key_id = Replace_with_the_correct_access_Key
    aws_secret_access_key = Replace_with_the_correct_secret_Key
```
3) Export your AWS credentials in order to use the rest of the commands:
```shell
export AWS_PROFILE=Replace_with_the_correct_profile_name
```
4) Install aws cli from https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html


## Usage

**1.** Fork this repository and [create the GitHub token granting access](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to this new repository in your account. Store this secret in AWS secrets manager using the aws cli.
```shell
aws secretsmanager create-secret --name ecs-github-token --secret-string "<github-token-created-above>"
```

**2.** Clone that recently forked repository from your account (not the one from the aws-sample organization) and change the directory to the appropriate one as shown below:

```bash
cd examples/core-infra/
```

**3.** Run Terraform init to download the providers and install the modules

```shell
terraform init
```

**4.** Review the terraform plan output, take a look at the changes that terraform will execute, and then apply them:

```shell
terraform plan
terraform apply
```

## Outputs

After the execution of the Terraform code you will get an output with needed IDs and values needed as input for the nexts Terraform applies.

## Cleanup

Run the following command if you want to delete all the resources created before:

```shell
terraform destroy
```
