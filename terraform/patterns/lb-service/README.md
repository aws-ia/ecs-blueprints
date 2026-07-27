# ECS load-balanced service

This self-contained example creates its own VPC, ECS cluster, Cloud Map namespace,
load-balanced frontend, and private companion backend. It no longer requires a separate
`core-infra` deployment or discovers resources by name.

## Deployment

This self-contained topology intentionally changes the cluster and VPC used by releases
that predate the v7 migration. Do not apply it to an existing shared-infrastructure state
as a routine in-place upgrade. Create a new backend key or workspace, deploy and validate
the replacement, shift traffic, and then retire the old service. This root intentionally
contains no migration state moves or v7 compatibility switches because it represents a
new topology and must start from new state. See the
[v7 migration guide](../../../docs/terraform-v7-migration.md) for state backup and plan
review requirements.

```shell
terraform init
terraform plan
terraform apply
terraform output -raw application_url
```

Set `name` to deploy another isolated copy in the same account and Region. The frontend
uses `backend.<name>.local:3000`; only the frontend task security group can reach that
backend port.

## HTTPS

The public Application Load Balancer listens on HTTP port 80 only, which keeps the demo
free of a domain-name prerequisite. For production use:

1. Create or import a certificate in AWS Certificate Manager (ACM) in the deployment
   Region for the domain that will point at the ALB.
2. Add an HTTPS listener on port 443 to the `alb` module (`protocol = "HTTPS"`,
   `certificate_arn` set to the ACM certificate) forwarding to the existing target
   group.
3. Change the port 80 listener to a `redirect` action returning `HTTP_301` to port 443
   so plaintext requests are upgraded to TLS.
4. Consider AWS WAF in front of the ALB for internet-facing workloads.

## Cost

This example creates one NAT gateway, an Application Load Balancer, five Fargate tasks,
Cloud Map services, and CloudWatch logs. Review current regional pricing and do not leave
the stack running when it is not in use.

## Quotas

Confirm VPC, NAT gateway, Fargate task, elastic network interface, load balancer, target
group, and Cloud Map quotas in the selected Region.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After deployment, request `application_url`, confirm targets are
healthy, and inspect frontend and backend ECS service events and CloudWatch Logs.

## Cleanup

Run `terraform destroy` from this directory. Networking, cluster, namespace, and both
services are owned by the same Terraform state and are removed together.
