# ECS backend service with Github Actions CI/CD

This solution blueprint creates a backend service that **does not** sit behind a load balancer. The backend service has a service discovery name registered with AWS Cloud Map. Other services running in this cluster can access the backend service using the service discovery name. Below are steps for deploying this service:

* Deploy the [core-infra](../core-infra/README.md). Note if you have already deployed the infra then you can reuse it as well.

* Now you can deploy this blueprint
  ```shell
  terraform init
  terraform plan
  terraform apply -auto-approve
  ```

<p align="center">
  <img src="../../docs/backend-service.png"/>
</p>

The solution has following key components:
* ECR registery for the container image. We are using only one container image for the task in this example.
* ECS service definition:
    * Task security group: allows ingress for TCP from all IP address in the VPC CIDR block to the container port (3000 in this example). And allows all egress.
    * Tasks for this service will be deployed in private subnet
    * Task definition consisting of task vCPU size, task memory, and container information including the above created ECR repository URL.
    * Task definition also takes the task execution role ARN which is used by ECS agent to fetch ECR images and send logs to AWS CloudWatch on behalf of the task.

## Setup for Github Actions

1. Provision the CI/CD resources defined in `cicd/`
2. Set Github action secrets
  - `AWS_DEFAULT_REGION` - The region where the resources are/will be provisioned
  - `AWS_IAM_ROLE` - The GitHub OIDC IAM role ARN; Terraform output `github_oidc_iam_role_arn`
