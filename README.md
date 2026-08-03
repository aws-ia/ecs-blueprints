# Amazon ECS Blueprints

Welcome to Amazon ECS Blueprints!

When **new users** want to adopt containers to build, deploy, and run their applications, it often takes them several months to  learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or host OS. With ECS Solution Blueprints, we want new users to **achieve benefits of container-based modernization in hours rather than months**!

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency.

We fully expect you to get started by copying the modules and examples but we **do not** expect you to maintain any conformity to this repository. In others words, we expect that you will adapt and extend the *modules* and *examples* code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Solution Blueprints.

## Which example should I start with?

Find your use case below. **Self-contained** examples create their own VPC and cluster —
clone, `terraform apply` once, and destroy cleanly. Examples marked **shared cluster**
require deploying the sibling `core-infra` example first. Examples marked **Yes\*** are
self-contained but bundle a CodePipeline/CodeBuild CI/CD pipeline, so before the service
has an image to run you must fork the app repo and provide a GitHub token — see that
example's README Prerequisites.

| I want to… | Start here | IaC | Self-contained? |
|---|---|---|---|
| Deploy a container image to an HTTPS endpoint with the least setup | [ECS Express Mode](./terraform/patterns/express-mode/) | Terraform + [CDK](./cdk/examples/express_mode/) | Yes |
| Run a public web service behind a load balancer | [lb-service](./terraform/patterns/lb-service/) | Terraform + CDK ([Python](./cdk/examples/lb_service/) & [TypeScript](./cdk/examples/lb_service/typescript/)) | Yes |
| Run a private backend/API service | [backend-service](./terraform/patterns/backend-service/) | Terraform + [CDK](./cdk/examples/backend_service/) | Yes |
| Connect microservices with Service Connect (TLS, access logs) | [service-connect](./terraform/patterns/service-connect/) | Terraform | Yes |
| Use blue/green, canary, or linear deployments (ECS native) | [native-deployment](./terraform/patterns/native-deployment/) | Terraform | Yes |
| Run containers on EC2 without managing ASGs/AMIs | [managed-instances](./terraform/patterns/managed-instances/) | Terraform | Yes |
| Run an IPv6-only workload | [ipv6-only](./terraform/patterns/ipv6-only/) | Terraform | Yes |
| Run on ARM64/Graviton for price-performance | [graviton](./terraform/patterns/graviton/) | Terraform | Yes\* |
| Process a queue with autoscaling workers | [sqs-dynamic-target-tracking](./terraform/patterns/sqs-dynamic-target-tracking/) | Terraform | Yes\* |
| Batch-process S3 uploads via SQS + scheduled scaling | [queue-processing](./terraform/patterns/queue-processing/) | Terraform | Yes\* |
| Build a CI/CD pipeline for a containerized app | [cicd-examples](./terraform/cicd-examples/) | Terraform + [CDK](./cdk/examples/cicd_service/) | See README |
| Collect metrics with Prometheus/ADOT and Amazon Managed Grafana | [prometheus](./terraform/patterns/prometheus/) | Terraform | Yes |
| Run tasks in private subnets without a NAT gateway | [vpc-endpoints](./terraform/patterns/vpc-endpoints/) | Terraform | Yes |
| Run an event-driven task from EventBridge | [event_bridge](./cdk/examples/event_bridge/) | CDK | Shared core stack |
| Run a data pipeline with Step Functions + ECS tasks | [data_pipeline](./cdk/examples/data_pipeline/) | CDK (Python + TypeScript) | Shared core stack |
| Chaos-test a service with AWS FIS | [fis_service](./cdk/examples/fis_service/) | CDK | Shared core stack |
| Build a GenAI chat/RAG app on Bedrock | [generative_ai_rag](./cdk/examples/generative_ai_rag/) | CDK | Shared core stack |
| Serve GenAI models via SageMaker + OpenSearch | [generative_ai_service](./cdk/examples/generative_ai_service/) | CDK | Shared core stack |
| Distributed ML training on GPUs (Ray) | [distributed-ml-training](./terraform/ec2-examples/distributed-ml-training/) | Terraform | Shared cluster |
| Distributed/GPU inference (Ray Serve, vLLM, Triton) | [ec2-examples](./terraform/ec2-examples/) | Terraform | Shared cluster |
| LLM inference on AWS Inferentia | [vllm-inferentia](./terraform/ec2-examples/vllm-inferentia/) | Terraform | Shared cluster |
| Host a developer portal (Backstage + Aurora) | [backstage](./terraform/fargate-examples/backstage/) | Terraform | Shared cluster |

**A note on CDK scope**: the CDK catalog is Python-first (the load-balanced service and
the data pipeline also ship in TypeScript) and covers the core service patterns, CI/CD,
events, chaos, and GenAI use cases. The Terraform catalog is broader — it is the primary home for the newer ECS
feature patterns and all EC2/ML workloads. Both are maintained; pick the language your
team operates in and check the table above for availability.

## Prerequisites

* macOS, Linux, or Windows with WSL2
* IaC Tool
  * [Terraform](https://developer.hashicorp.com/terraform/install) 1.5.7 or newer
  * [AWS CDK](https://docs.aws.amazon.com/cdk/v2/guide/getting-started.html) v2
* [Git](https://github.com/git-guides/install-git)
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* Python 3.12 and Node.js 22 for local validation
* A dedicated AWS sandbox account and short-lived credentials configured using
  [AWS IAM Identity Center](./docs/authentication.md)

## Quick Start for ECS Blueprints for Terraform

Please refer [ECS Blueprints Workshop](https://catalog.workshops.aws/ecs-solution-blueprints/en-US) in detail.

* Fork this repository.

* Clone your forked repository to your workstation.

```shell
git clone https://github.com/<your-repo>/ecs-blueprints.git
```

* Start with a self-contained pattern, which creates and destroys its own VPC, cluster, and
  service in one Terraform root.

```shell
cd ecs-blueprints/terraform/patterns/service-connect

terraform init
terraform plan
terraform apply --auto-approve
```

The `core-infra` examples remain as an intentional shared-cluster topology reference. They
are not a prerequisite for new patterns.

Existing deployments should follow the
[Terraform ECS module v7 migration guide](./docs/terraform-v7-migration.md) before applying
the updated examples to state created by module v5.

Self-contained patterns (own VPC and cluster, single apply and destroy):

* [Load-balanced Service](./terraform/patterns/lb-service/README.md)
* [Backend Service](./terraform/patterns/backend-service/README.md)
* [ECS Express Mode](./terraform/patterns/express-mode/README.md)
* [Native ECS deployments](./terraform/patterns/native-deployment/README.md)
* [ECS Managed Instances](./terraform/patterns/managed-instances/README.md)
* [Service Connect microservices](./terraform/patterns/service-connect/README.md)
* [Graviton](./terraform/patterns/graviton/README.md)
* [SQS Autoscaling](./terraform/patterns/sqs-dynamic-target-tracking/README.md)
* [Queue Processing](./terraform/patterns/queue-processing/README.md)
* [Amazon Managed Prometheus and Grafana](./terraform/patterns/prometheus/README.md)
* [VPC Endpoints](./terraform/patterns/vpc-endpoints/README.md)
* [IPv6-only Fargate](./terraform/patterns/ipv6-only/README.md)

Shared-cluster examples (deploy [core-infra](./terraform/fargate-examples/core-infra/README.md) first):

* [Backstage developer portal](./terraform/fargate-examples/backstage/README.md)


## Repository overview

The primary code is organized into Terraform, CDK, and sample-application areas:

* [modules](./terraform/modules/): Each module is a collection one or more resources that are used together to address specific needs. If you are going to contribue new modules, that is, commonly used group of resources, then put them in the *modules* folder.
* [patterns](./terraform/patterns/): Self-contained blueprints that create their own
  networking, cluster, and workload — the primary catalog and the destination for
  converted examples.
* [fargate-examples](./terraform/fargate-examples/): Shared-cluster examples built on the
  `core-infra` topology reference; these convert to `patterns/` incrementally (see
  [repository structure](./docs/repository-structure.md)).
* [EC2 examples](./terraform/ec2-examples/): ECS workloads that use EC2 capacity.
* [CI/CD examples](./terraform/cicd-examples/): Pipeline and external-state topologies.
* [CDK examples](./cdk/examples/): Python and TypeScript ECS applications.
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
