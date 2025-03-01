# Fargate Examples

This folder contains solution blueprints that are meant to address end-to-end requirements for specific scenarios. An example of a scenario would be a new user, without existing ECS Fargate infrastructure, looking to build, deploy, and run a load balanced service.

## Modules

These modules work together to create a working fargate setup.

- **[state-management](./state-management/README.md):** This module creates the S3 bucket and DynamoDB table necessary to store Terraform state remotely. It should be deployed first.
- **[core-infra](./core-infra/README.md):** This module sets up the core ECS Fargate infrastructure, including the VPC, ECS cluster, and service discovery.
- **[lb-service](./lb-service/README.md):** This module demonstrates how to deploy and run a load-balanced service on Fargate, using the infrastructure created by `core-infra`.

## Getting Started

For first-time users, the recommended order of deployment is:

1.  **[state-management](./state-management/README.md):** Deploy this module first to create the infrastructure for remote state storage. This will allow all other modules to store their state remotely.
2.  **[core-infra](./core-infra/README.md):** Deploy this module to set up the required ECS Fargate infrastructure.
3.  **[lb-service](./lb-service/README.md):** Deploy this module to see an example of a load-balanced service running on the infrastructure from `core-infra`.

## Remote State Storage

All modules should be configured to use remote state storage using the S3 bucket and DynamoDB table created by the `state-management` module.

### Setting up Remote State

To set up remote state, follow these steps.

1. Create the `backend.tfvars` file in the root of the project, next to the `state-management` folder.

```terraform
bucket         = "cleanlink-portal-api-terraform-state-eu-west-2" # Update this value
region         = "eu-west-2" #Update this value
dynamodb_table = "cleanlink-portal-api-terraform-state-lock-table" # Update this value
```

Run the apply command in the root of the project.

```
$ terraform apply
```

Run the init command in the state-management folder.

```
$ terraform init -backend-config=../backend.tfvars
```

Update the backend.tf file in the state-management folder to look like this.

```terraform
terraform {
  backend "s3" {
    key     = "state-management/terraform.tfstate"
    encrypt = true
  }
}
```

Run the apply command.

```
$ terraform apply
```

### Configuring backend.tf for Modules

When creating a new module, you'll need to add a backend.tf file in the root of the module directory. This tells Terraform to store its state remotely. Here's how to configure it:

Create a new file in the root of your module, and add the following.

```terraform
terraform {
  backend "s3" {
    key            = "<PUT MODULE NAME HERE>/terraform.tfstate" # Customize the key (path/filename)
    encrypt        = true                                       # Enable server-side encryption
  }
}
```

Make sure when running terraform init in the module directory, you specify the -backend-config=../backend.tfvars flag to point to the common remote state configuration.

```
$ terraform init -backend-config=../backend.tfvars
```

Run the apply command.

```
$ terraform apply
```
