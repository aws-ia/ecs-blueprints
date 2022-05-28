<!-- BEGIN_TF_DOCS -->
# Amazon ECS Blueprints for Terraform

## Table of content

   * [Solution overview](#solution-overview)
   * [General information](#general-information)
   * [Solution-based scenarios](#solution-based-scenarios)
      * [Usage](#usage)
   * [Security](#security)
   * [License](#license)


## Solution overview

This repository contains Terraform code to deploy a solution that is intended to be used to run a demo. It shows how AWS resources can be used across different scenarios to build an architecture that reduces defects while deploying, eases remediation, mitigates deployment risks and improves the flow into production environments while gaining the advantages of a managed underlying infrastructure for containers.

## General information

The project has been divided into different parts:
- Application code: the code for the running full-stack application
    - client: Vue.js code for the frontend application
    - server: Node.js code for the backend application
- Modules: reusable parametrized Terraform modules to be used across multiple examples
- Examples: contains the Terraform code to deploy the needed AWS resources for specific examples
- Templates: templates used across examples (i.e. definition of ECS tasks, CodeDeply files, etc)

## Solution-based scenarios

The examples folder contains the terraform code to deploy the AWS resources. The *Modules* folders have been created to store the Terraform modules used in this project. The *Templates* folder contains the different configuration files needed within the modules. The Terraform state is stored locally in the machine where you execute the terraform commands, but feel free to set a Terraform backend configuration like an AWS S3 Bucket or Terraform Cloud to store the state remotely. The scenarios to deply are the followings:

- Core Infra: this folder contains all the core Infrastructure needed accross any other scenario
- Deployments
    - Blue/Green: a Blue/Green deployment methodology implemented with CodeDeploy
    - Rolling: a rolling deployment mthodology implemented with the native ECS deployment feature

## Usage

**1.** Fork this repository and create the GitHub token granting access to this new repository in your account.

**2.** Read the readme of each scenario (folder). For any scenario you must deploy the core infrastructure (core\_infra folder) first.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License
This library is licensed under the Apache-2.0 License. See the [LICENSE](LICENSE) file.

<!-- END_TF_DOCS -->
