# ECS load-balanced service

This solution blueprint creates a web-facing load balanced ECS service. There are two steps to deploying this service:

* Deploy the [core-infra](../core-infra/README.md). Note if you have already deployed the `core-infra` then you can reuse it.
* Deploy this blueprint using the below commands
```shell
terraform init
terraform plan
terraform apply -auto-approve
```

<p align="center">
  <img src="../../../docs/lb-service.png"/>
</p>

The solution has following key components:

* ALB: We are using Application Load Balancer for this service. Note the following key attributes for ALB:
    * ALB security group - allows ingress from any IP address to port 80 and allows all egress
    * ALB subnet - ALB is created in a public subnet
    * Listener - listens on port 80 for protocol HTTP
    * Target group - Since we are using Fargate launch type, the targe type is IP since each task in Fargate gets its own ENI and IP address. The target group has container port (3000) and protocol (HTTP) where the application container will serve requests. The ALB runs health check against all registered targets. In this example, ALB send HTTP GET request to path "/" to container port 3000. We are using target group default health check settings. You can tune these settings to adjust the time interval and frequency of health checks. It impacts how fast tasks become available to serve traffic. (See [ALB target health check documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html) to learn more.)
* ECR registery for the container image. We are using only one container image for the task in this example.
* ECS service definition:
    * Task security group: allows ingress for TCP from the ALB security group to the container service port (3000 for this example). And allows all egress.
    * Service discovery: You can register the service to AWS Cloud Map registry. You just need to provide the `namespace` but make sure the namespace is created in the `core-infra` step.
    * Tasks for this service will be deployed in private subnet
    * Service definition takes the load balancer target group created above as input.
    * Task definition consisting of task vCPU size, task memory, and container information including the above created ECR repository URL.
    * Task definition also takes the task execution role ARN which is used by ECS agent to fetch ECR images and send logs to AWS CloudWatch on behalf of the task.

## Cost

This example creates billable AWS resources. Review `terraform plan`, use a sandbox account, and avoid leaving the stack deployed when it is not in use. NAT gateways, load balancers, databases, and accelerated instances are common cost drivers where present.

## Quotas

Confirm that the target Region has sufficient ECS task, elastic network interface, load balancer, and any workload-specific service quotas before deployment. EC2 examples also require available capacity for the selected instance types.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review `terraform plan` before applying. After deployment, use the functional check described above and inspect ECS service events and CloudWatch Logs for task failures.

## Cleanup

Run `terraform destroy` from this example directory. Remove retained data or separately created secrets only after confirming they are no longer needed.
