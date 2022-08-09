# Amazon ECS Solution Blueprints for Terraform
Welcome to Amazon ECS Solution Blueprints for Terraform!

When **new users** want to adopt containers to build, deploy, and run their applications, it often takes them several months to  learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or and host OS. With ECS Solution Blueprints, we want new users to **achieve benefits of container-based modernization in hours rather than months**!

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency.

We fully expect you to get started by copying the modules and examples but we **do not** expect you to maintain any conformity to this repository. In others, we expect that you will adapt and extend the *modules* and *examples* code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Solution Blueprints.

## Prerequisites
* You can use [AWS Cloud9](https://aws.amazon.com/cloud9/) which has all the prerequisites preinstalled and skip to [Getting Started](#getting-started)
* Mac (tested with OS version 12.+) and AWS Cloud9 Linux machines. We have **not tested** with Windows machines
* [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (tested version v1.2.5 on darwin_amd64)
* [Git](https://github.com/git-guides/install-git) (tested version 2.27.0)
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
* AWS test account with administrator role access
* Configure the AWS credentials on your machine `~/.aws/credentials`. You need to use the following format:
```shell
[AWS_PROFILE_NAME]
aws_access_key_id = Replace_with_the_correct_access_Key
aws_secret_access_key = Replace_with_the_correct_secret_Key
```
* Export the AWS profile name
```bash
export AWS_PROFILE=your_profile_name
```
* You can also set the default region and output format in `~/.aws/config`. Something like:
```shell
[default]
output = json
region = us-west-2
```
## Quick Start
* Fork this repository.
* Create a [Github token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) to access the forked repository.
* Store the secret in AWS Secrets Manager in the region where you want to deploy the blueprints.
```shell
aws secretsmanager create-secret --name ecs-github-token --secret-string <your-github-access-token>
```
* Clone your forked repository to your laptop/Cloud9 VM.
```shell
git clone https://github.com/<your-repo>/terraform-aws-ecs-blueprints.git
```
* Start with `core-infra` to create cluster, VPC, and require IAM
```shell
cd terraform-aws-ecs-blueprints/examples/core-infra/

terraform init

cp terraform.tfvars.example terraform.tfvars

vim terraform.tfvars
# edit the region name in the terraform.tfvars to your region where you created the secret
```
* Run terraform commands to deploy infrastructure
```shell
terraform plan
terraform apply --auto-approve
```
* Now we can deploy a load balanced service along with CI/CD pipeline to the above cluster
```shell
cd ../lb-service
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
# change the repository owner to your repo owner name and set aws region to ECS cluster region
```
* Deploy the load balanced service and CI/CD pipeline
```shell
terraform init
terraform plan
terraform apply --auto-approve
```
You can use the ALB URL from terraform output to access the load balanced service. The above will give you a good understanding about the basics of ECS Fargate, ECS service, and CI/CD pipelines using AWS CodeBuild and AWS CodePipeline services. You can use these as building blocks to create and deploy many ECS services where each service has its independent infra-as-code repository, separate CI/CD pipeline, and gets deployed in an ECS cluster such as dev, staging, or production. Next you can try other example blueprints.
* [VPC Endpoints](./examples/vpc-endpoints/README.md)
* [Backend Service](./examples/backend-service/README.md)
* [Amazon Managed Prometheus and Grafana](./examples/prometheus/README.md)
* [2-Tier DynamoDB Application (Rolling Deployment)](./examples/rolling-deployment/README.md)
* [2-Tier DynamoDB Application (Blue/Green Deployment)](./examples/blue-green-deployment/README.md)

## Repository overview
This repository has 3 main folders
* [modules](./modules): Each module is a collection one or more resources that are used together to address specific needs. For example, [ecs-service](./modules/ecs-service) has resources for ECS service definition, task definition, task related IAM roles, and autoscaling. These resources are often used together in defining an ECS service. If you are going to contribue new modules, that is, commonly used group of resources, then put them in the *modules* folder.
* [examples](./examples) (aka solution blueprints): This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. The [lb-service](./examples/lb-service), for example, creates load balanced service along with CI/CD pipeline with rolling deployment. All required services such as CodeBuild, CodePipeline and required resources such as load balancer, target group, security group are setup in the lb-service blueprint. If you are going to contribute new blueprints, put them in the *examples* folder.
* [application-code](./application-code): These are just sample applications used in the examples. Currently, these applications are basic but we encourage contributing more real world applications that can help uncover specific aspects of containerized applications. For example, an application that can be used to test autoscaling, or an application that has long running sessions and would work better with blue/green deployments.

## Support & Feedback

ECS Blueprints for Terraform is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the ECS Blueprints community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues](https://github.com/aws-ia/terraform-aws-ecs-blueprints/issues) section of this GitHub repository.

For architectural details, step-by-step instructions, and customization options, see our documentation under each folder.

If you are interested in contributing to ECS Blueprints, see the [Contribution guide](CONTRIBUTING.md).

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for more information.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.
