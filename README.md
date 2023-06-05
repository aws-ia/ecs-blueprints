# Amazon ECS Blueprints

Welcome to Amazon ECS Blueprints!

When **new users** want to adopt containers to build, deploy, and run their applications, it often takes them several months to  learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or host OS. With ECS Solution Blueprints, we want new users to **achieve benefits of container-based modernization in hours rather than months**!

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency.

We fully expect you to get started by copying the modules and examples but we **do not** expect you to maintain any conformity to this repository. In others words, we expect that you will adapt and extend the *modules* and *examples* code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Solution Blueprints.

## Prerequisites

* You can use [AWS Cloud9](https://aws.amazon.com/cloud9/) which has all the prerequisites preinstalled and skip to [Quick Start](#quick-start)
* Mac (tested with OS version 12.+) and AWS Cloud9 Linux machines. We have **not tested** with Windows machines
* IaC Tool
  * [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (tested version v1.3.7 on darwin_amd64)
  * [AWS CDK](https://aws.amazon.com/cdk/) (tested vision 2.70.+)
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

## Quick Start for ECS Blueprints for Terraform

Please refer [ECS Blueprints Workshop](https://catalog.workshops.aws/ecs-solution-blueprints/en-US) in detail.

* Fork this repository.

* Clone your forked repository to your laptop/Cloud9 VM.

```shell
git clone https://github.com/<your-repo>/ecs-blueprints.git
```

* Start with `core-infra` to create cluster, VPC, and require IAM

```shell
cd ecs-blueprints/terraform/fargate-examples/core-infra/

terraform init
terraform plan
terraform apply --auto-approve
```
* Now we can deploy a load balanced service along with CI/CD pipeline to the above cluster

```shell
cd ../lb-service
terraform init
terraform plan
terraform apply --auto-approve
```

You can use the ALB URL from terraform output to access the load balanced service. The above will give you a good understanding about the basics of ECS Fargate, and ECS service. You can use these as building blocks to create and deploy many ECS services. Next you can try other example blueprints.

* [Backend Service](./terraform/fargate-examples/backend-service/README.md)
* [Graviton](./terraform/fargate-examples/graviton/README.md)
* [Amazon Managed Prometheus and Grafana](./terraform/fargate-examples/prometheus/README.md)
* [VPC Endpoints](./terraform/fargate-examples/vpc-endpoints/README.md)
* [Queue Processing](./terraform/fargate-examples/queue-processing/README.md)


## Repository overview

This repository has 3 main folders

* [modules](./terraform/modules/): Each module is a collection one or more resources that are used together to address specific needs. If you are going to contribue new modules, that is, commonly used group of resources, then put them in the *modules* folder.
* [examples](./terraform/fargate-examples/) (aka solution blueprints): This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. If you are looking to contribute new blueprints, put them in the *examples* folder.
* [application-code](./application-code): These are just sample applications used in the examples. Currently, these applications are basic but we encourage contributing more real world applications that can help uncover specific aspects of containerized applications. For example, an application that can be used to test autoscaling, or an application that has long running sessions and would work better with blue/green deployments.

## Support & Feedback

ECS Blueprints for Terraform is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the ECS Blueprints community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues](https://github.com/aws-ia/ecs-blueprints/issues) section of this GitHub repository.

For architectural details, step-by-step instructions, and customization options, see our documentation under each folder.

If you are interested in contributing to ECS Blueprints, see the [Contribution guide](CONTRIBUTING.md).

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for more information.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.
