# Amazon ECS Blueprints for CDK

Welcome to Amazon ECS Blueprints for CDK Python!

When new users want to adopt containers to build, deploy, and run their applications, it often takes them several months to learn, setup, and realize container benefits. With [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/) and [AWS Fargate](https://aws.amazon.com/fargate/) users don't need to manage any middleware, any EC2, or host OS. With ECS Blueprints, we want new users to achieve benefits of container-based modernization in hours rather than months!

The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With blueprints, we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency.

We fully expect you to get started by copying the modules and examples but we do not expect you to maintain any conformity to this repository. In others, we expect that you will adapt and extend the modules and examples code to suit your needs. If you feel your use cases and solutions will help other users, we encourage you to contribute your solutions to ECS Blueprints.

## Prerequisites

---

- macOS, Linux, or Windows with WSL2
- Python 3.12 and Node.js 22
- [AWS CDK Toolkit](https://docs.aws.amazon.com/cdk/v2/guide/cli.html) v2
- [Git](https://github.com/git-guides/install-git)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- A dedicated AWS sandbox account using
  [short-lived credentials](../docs/authentication.md)

## Quick Start

---

- Fork this repository
- Create a [Github token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) to access the forked repository. This is only needed when you're going through [cicd_service](./examples/cicd_service).

```bash
aws secretsmanager create-secret --name ecs-github-token --secret-string <your-github-access-token>
```

- Clone your forked repository to your workstation

```bash
git clone https://github.com/<your-repo>/ecs-blueprints.git
```

- Start with a self-contained example that creates and destroys its VPC, cluster, and
  workload as one stack:

```bash
cd ecs-blueprints/cdk/examples/lb_service/
```

- [`lb_service`](./examples/lb_service) creates a public frontend and private companion
  backend. A TypeScript version is available in
  [`lb_service/typescript`](./examples/lb_service/typescript).
- [`backend_service`](./examples/backend_service) creates a private service with Cloud Map.
- [`express_mode`](./examples/express_mode) compares image-based and custom-task-definition
  Express Mode.

The [`core_infra`](./examples/core_infra) app remains as an intentional shared-cluster
topology reference. It is not a prerequisite for the self-contained examples.

## Repository overview

This folder is organized so that everything under [examples](./examples) is a
starting point you can deploy as-is:

- [examples](./examples) (aka solution blueprints): Each subfolder is a startable
  CDK app — `cd` into it, create a `.env` from `sample.env`, and `cdk synth`/`cdk deploy`.
  These are end-to-end, self-contained scenarios built from stock AWS CDK constructs.
  Each new example should own its networking, cluster, and workload unless it explicitly
  demonstrates the shared cluster topology (see [core_infra](./examples/core_infra)).
- Examples that also ship in TypeScript keep the TypeScript app in a `typescript/`
  subfolder with its own `package.json`, tests, and README, alongside the Python app
  (see [lb_service/typescript](./examples/lb_service/typescript) and
  [data_pipeline/typescript](./examples/data_pipeline/typescript)). The TypeScript apps
  use `npm ci && npx cdk deploy` and read the account/Region from the CLI environment
  instead of a `.env` file.
- [components](./components): Shared constructs and helpers reused across examples
  (for example, the core infrastructure construct and CI/CD construct). These are not
  deployable apps; examples import them as the `components` package.
- Each example's `lib/` folder holds the stacks private to that example. Supporting
  stacks live with the example that uses them (for example, the Bedrock stack under
  `generative_ai_rag/lib/` and the SageMaker/OpenSearch stacks under
  `generative_ai_service/lib/`).
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
