# Amazon ECS Solution Blueprints for Terraform

Welcome to Amazon ECS Solution Blueprints for Terraform!

When **new users** want to adopt containers to build, deploy, and run their applications, it often takes them several months to  learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or and host OS. With ECS Solution Blueprints, we want new users to **achieve benefits of container-based modernization in hours rather than months**! 

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency. 

We fully expect you to get started by copying the modules and examples but we **do not** expect you to maintain any conformity to this repository. In others, we expect that you will adapt and extend the *modules* and *examples* code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Solution Blueprints.

## Repository overview
This repository has 3 main folders
* [modules](./modules): Each module is a collection one or more resources that are used together to address specific needs in a container workflow. For example, [ecs-service](./modules/ecs-service) has resources for ECS service definition, task definition, task related IAM roles, and autoscaling. These resources are often used together in defining an ECS service. If you are going to contribue new modules, that is, commonly used group of resources, then put them in the *modules* folder.
* [examples](./examples) (aka solution blueprints): This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. The [lb-service](./examples/lb-service), for example, creates load balanced service along with CI/CD pipeline with rolling deployment. All required services such as CodeBuild, CodePipeline and required resources such as load balancer, target group, security group are setup in the lb-service blueprint. If you are going to contribute new blueprints, put them in the *examples* folder.
* [application-code](./application-code): These are just sample applications used in the examples. Currently, these applications are basic but we encourage contributing more real world applications that can help uncover specific aspects of containerized applications. For example, an application that can be used to test autoscaling, or an application that has long running sessions and would work better with blue/green deployments.


```
├── application-code            # Application source code for CI/CD
│   ├── client
│   ├── ecsdemo-frontend
│   ├── ecsdemo-nodejs
│   └── server
├── docs
├── examples                    # Terraform Deployment Patterns
│   ├── backend-service
│   ├── blue-green-deployment
│   ├── core-infra
│   ├── lb-service
│   └── rolling-deployment
├── modules                     # Terraform Modules used in examples
    ├── codebuild
    ├── codedeploy
    ├── codepipeline
    ├── ecs-backend-service
    └── ecs-service
```

## Prerequisites
The ECS solution blueprints with Terraform assumes you have:
* Basic understanding of Docker containers, and how to create them using Dockerfiles.
* Intermediate level of Terraform knowledge, that is, you have used Terraform to create and manage AWS resources before. 

### Prerequisites for your laptop
* Mac (strongly recommended) - We have tested using Mac (tested version 12.4) and AWS Cloud9 Linux machines. We have **not tested** at all with Windows laptops.
* Terraform (tested version v1.2.5 on darwin_amd64)
* Git (tested version 2.27.0)
* AWS account access setup on laptop - We are working on documenting the least privilege user roles that are needed but for now Administrator access on Test (strictly non-production) accounts is recommended.

## Getting Started

* Clone this repository
* Start with the [core-infra](./examples/core-infra/README.md). This will create the ECS cluster, VPC, subnets, and IAM roles required to run you containers.
* Deploy the [lb-service](./example/lb-service/README.md). This will create a load-balanced ECS service along with CI/CD pipeline.
* Deploy the [backend-service](./example/backend-service/README.md). This will create a backend ECS service **without** a load balancer.

The above will give you a good understanding about the basics of ECS Fargate, ECS service, and CI/CD pipelines using AWS CodeBuild and AWS CodePipeline services. You can use these as building blocks to create and deploy many ECS services where each service has its independent infra-as-code repository, separate CI/CD pipeline, and gets deployed in an ECS cluster such as dev, staging, or production.

Another common pattern is to deploy both frontend (client) and backend (server) services with load balancers along with a database service (such as DynamoDB). This would be like a 2-Tier DynamoDB application which can be deployed using below examples.
* [2-Tier DynamoDB Application (Rolling Deployment)](./examples/rolling-deployment/README.md)
* [2-Tier DynamoDB Application (Blue/Green Deployment)](./examples/blue-green-deployment/README.md)


## Support & Feedback

ECS Blueprints for Terraform is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the ECS Blueprints community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues](https://github.com/aws-ia/terraform-aws-ecs-blueprints/issues) section of this GitHub repository.

For architectural details, step-by-step instructions, and customization options, see our documentation under each folder.

If you are interested in contributing to ECS Blueprints, see the [Contribution guide](CONTRIBUTING.md).


## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for more information.


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.
