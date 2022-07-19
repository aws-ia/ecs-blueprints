# Amazon ECS Blueprints for Terraform

Welcome to Amazon ECS Blueprints for Terraform!

This repository contains a collection of Terraform modules that aim to make it easier and faster for customers to adopt [Amazon ECS and Fargate](https://aws.amazon.com/ecs/). It can be used by AWS customers, partners, and internal AWS teams to provision a number of architectural `blueprints` using ECS and Fargate.

Start with the architectural blueprint that most closely matches your use case.  The following is a list of supported blueprints:

- [ ] Load Balanced Web Service
- [ ] Load Balanced Web Service (with NLB)
- [ ] Load Balanced Web Service (with CI/CD Pipeline)
- [ ] Load Balanced Web Service (with CI/CD Pipeline with Blue/Green Deployment)
- [ ] Load Balanced Web Service (with Github Actions)
- [ ] API Gateway Web Service
- ✅ [Backend Service](./examples/backend-service/README.md)
- [ ] Worker Service
- [ ] Scheduled Task
- ✅ [2-Tier DynamoDB Application (Rolling Deployment)](./examples/rolling-deployment/README.md)
- ✅ [2-Tier DynamoDB Application (Blue/Green Deployment)](./examples/blue-green-deployment/README.md)


## Motivation


## Support & Feedback

ECS Blueprints for Terraform is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the ECS Blueprints community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues](https://github.com/aws-ia/terraform-aws-ecs-blueprints/issues) section of this GitHub repository.

For architectural details, step-by-step instructions, and customization options, see our documentation under each folder.

If you are interested in contributing to ECS Blueprints, see the [Contribution guide](CONTRIBUTING.md).


## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for more information.


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.
