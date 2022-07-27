# Core Infrastructure
This folder contains the Terraform code to deploy the core infratructure for an ECS Fargate workload. The AWS resources created by the script are:
* Networking
  * VPC
    * 3 public subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of public subnets as AZs.
    * 3 private subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of private subnets as AZs.
    * 1 NAT Gateway
    * 1 Internet Gateway
    * Associated Route Tables
* 1 ECS Cluster with AWS CloudWatch Container Insights enabled.
* Task execution IAM role
* CloudWatch log groups

## Getting Started 
Make sure you have all the [prerequisites](#prerequisites) for your laptop.

Fork this repository and [create the GitHub token granting access](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to this new repository in your account. Store this secret in AWS secrets manager using the aws cli.
```shell
aws secretsmanager create-secret --name ecs-github-token --secret-string "<github-token-created-above>"
```
Note you should create the secret in an AWS region where you plan to deploy the various examples. You can set the default region by exporting the environment variable `export AWS_DEFAULT_REGION=<default-region>` or in `~/.aws/config`.

## Usage
* Clone the forked repository from your account (not the one from the aws-ia organization) and change the directory to the appropriate one as shown below:
```bash
cd examples/core-infra/
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
