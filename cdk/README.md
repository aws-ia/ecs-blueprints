# Amazon ECS Blueprints for CDK

Welcome to Amazon ECS Blueprints for CDK Python!

When new users want to adopt containers to build, deploy, and run their applications, it often takes them several months to learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or host OS. With ECS Blueprints, we want new users to achieve benefits of container-based modernization in hours rather than months!

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints, we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency.

We fully expect you to get started by copying the modules and examples but we do not expect you to maintain any conformity to this repository. In others, we expect that you will adapt and extend the modules and examples code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Blueprints.

## Prerequisites

---

- You can use [AWS Cloud9](https://aws.amazon.com/cloud9/) which has all the prerequisites preinstalled and skip to Getting Started
- Mac and AWS Cloud9 Linux machines. We have not tested with Windows machines
- [AWS CDK Toolkit](https://docs.aws.amazon.com/cdk/v2/guide/cli.html)(tested with version 2.70.+)
- [Git](https://github.com/git-guides/install-git)(tested version 2.37.0)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
- AWS test account with administrator role access
- Configure the AWS credentials on your machine `~/.aws/credentials`. You need to use the following format:

```bash
[AWS_PROFILE_NAME]
aws_access_key_id = Replace_with_the_correct_access_Key
aws_secret_access_key = Replace_with_the_correct_secret_Key
```

- Export the AWS profile name

```bash
export AWS_PROFILE=your_profile_name
```

- You can also set the default region and output format in `~/.aws/config`. Something like:

```bash
[default]
output = json
region = us-west-2
```

## Quick Start

---

- Fork this repository
- Create a [Github token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) to access the forked repository. This is only needed when you're going through [cicd_service](./examples/cicd_service).

```bash
aws secretsmanager create-secret --name ecs-github-token --secret-string <your-github-access-token>
```

- Clone your forked repository to your laptop/Cloud9 VM

```bash
git clone https://github.com/<your-repo>/ecs-blueprints.git
```

- Start with `core_infra` to create cluster, VPC, and require IAM

```bash
cd ecs-blueprints/cdk/examples/core_infra/
```

- Next you can try other example blueprints.

## Repository overview

This repository has 2 main folders

- [examples](./examples) (aka solution blueprints): This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. The [lb_service](./examples/lb_service), for example, creates load balanced service along with CI/CD pipeline with rolling deployment. All required services such as CodeBuild, CodePipeline and required resources such as load balancer, target group, security group are setup in the lb-service blueprint. If you are going to contribute new blueprints, put them in the *examples* folder.
- [application-code](../application-code): These are just sample applications used in the examples. Currently, these applications are basic but we encourage contributing more real world applications that can help uncover specific aspects of containerized applications. For example, an application that can be used to test autoscaling, or an application that has long running sessions and would work better with blue/green deployments.

## Support & Feedback

ECS Blueprints for CDK is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the ECS Blueprints community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues](https://github.com/aws-ia/ecs-blueprints/issues) section of this GitHub repository.

For architectural details, step-by-step instructions, and customization options, see our documentation under each folder.

## Cleanup
To proceed with deleting the stack, use `cdk destroy` at each stack's folder.
```bash
cdk destroy
```
