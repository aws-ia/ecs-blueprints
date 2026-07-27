# Service Connect microservices

This self-contained pattern creates a VPC, ECS cluster, and three Fargate services:
`frontend`, `api`, and `backend`. The frontend has a public Application Load Balancer.
Service Connect exposes the private aliases `api:80` and `backend:80`, records Envoy access
logs as JSON, and enforces request and idle timeouts.

```shell
terraform init
terraform apply
```

To verify the service mesh, start an ECS Exec shell in a frontend task and run
`wget -qO- http://api`. From an API task, run `wget -qO- http://backend`. Service Connect
proxy logs are in `/aws/ecs/<name>/service-connect`.

The services enable Availability Zone rebalancing and span three subnets. AWS provider
6.56 does not yet expose the Service Connect zone-aware routing setting; use the ECS
service details and proxy metrics to confirm zone-local routing when provider support is
available.

## TLS

Pass an existing ACM Private CA ARN to encrypt Service Connect traffic:

```shell
terraform apply -var='private_ca_arn=arn:aws:acm-pca:REGION:ACCOUNT:certificate-authority/ID'
```

The pattern creates the required ECS infrastructure role. ACM Private CA is intentionally
optional because it has a significant fixed monthly cost.

## Cross-account namespace

Set `service_connect_namespace_arn` to a Cloud Map HTTP namespace shared through AWS RAM.
The namespace owner must create and accept the resource share and grant the participant
account permission before this stack is applied.

## Cost

This pattern creates one NAT gateway, one Application Load Balancer, six Fargate tasks,
and CloudWatch log groups. Optional ACM Private CA has a separate fixed monthly charge.
Review current regional pricing and reduce desired counts for short-lived experiments if
needed.

## Quotas

Confirm VPC, Fargate task, load balancer, Cloud Map namespace, Service Connect service, and
Private CA quotas. Cross-account use also requires available AWS RAM resource shares.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After applying, request `frontend_url`, run the ECS Exec checks above,
and inspect Service Connect access logs for both aliases.

## Cleanup

Run `terraform destroy` from this directory. A cross-account namespace supplied through
`service_connect_namespace_arn` is not owned or deleted by this pattern.
