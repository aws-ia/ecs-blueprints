This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. An example of a scenario would be a new user, without existing ECS Fargate infrastructure, looking to build, deploy, and run a load balanced service. The ECS Fargate infrastructure need is addressed by [core-infra](./core-infra/README.md) and the rest of needs to deploy, and run a load balanced service are addressed by [lb-service](./lb-service/README.md).

For first time users, [core-infra](./core-infra/README.md) is the recommended blueprint example to start because it will setup the required ECS Fargate infrastructure used in other examples.

If you are looking to contribute a new solution, then you will add your Terraform code in a new folder here. You can also contribute by improving existing solutions across many aspects of CI/CD, observability, security, and cost optimization.

Please consult documentation in specific example folder to learn more and try them!
