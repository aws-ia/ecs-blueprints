# IPv6-only Fargate service

This self-contained pattern runs Fargate tasks in IPv6-native private subnets. A public
Application Load Balancer uses dual-stack public subnets and an IPv6 target group, but its
public DNS advertises only IPv6 by using `dualstack-without-public-ipv4`. Outbound task
traffic uses an egress-only internet gateway, so the pattern has no NAT gateway.

## Prerequisite: enable the dualStackIPv6 account setting

IPv6-only ECS tasks require the Region-wide ECS `dualStackIPv6` account default to be
enabled. This is a one-time, account-wide setting shared by every ECS service, so this
pattern does **not** manage it by default (that keeps `terraform apply`/`destroy` from
flipping an account-wide setting other workloads may rely on). Enable it once per account
and Region before applying:

```shell
aws ecs put-account-setting-default --name dualStackIPv6 --value enabled --region us-west-2
```

Then deploy:

```shell
terraform init
terraform apply
curl -6 "$(terraform output -raw application_url)"
```

In a dedicated account you can instead let this root manage the setting with
`-var="manage_account_setting=true"`; note that `terraform destroy` will then disable it
again.

## Connectivity

Tasks pull the sample image from Docker Hub, whose registry and authentication endpoints
publish native AAAA records. `public.ecr.aws` does not currently provide the native IPv6
path this pattern requires. ECR interface VPC endpoints are also IPv4-only, so adding them
does not replace the egress-only internet route. Verify the registry, authentication, and
redirect hosts for every external dependency publish AAAA records before moving an
existing workload to IPv6-only subnets.

For a staged migration, retain dual-stack public load-balancer subnets, create a separate
IPv6 target group, and shift one ECS service at a time. Do not remove IPv4 from shared
subnets until every workload, VPC endpoint, DNS dependency, and operator network has been
tested over IPv6.

## Cost

This pattern creates an Application Load Balancer, Fargate tasks, and CloudWatch log
groups. It deliberately avoids NAT gateway hourly and data-processing charges. Standard
IPv6 public-address and data-transfer pricing still applies.

## Quotas

Confirm VPC IPv6 CIDR, subnet, route table, Fargate task, elastic network interface, load
balancer, and target group quotas. The selected Region must support IPv6-only ECS tasks and
the `dualstack-without-public-ipv4` load balancer mode.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After applying, resolve the load balancer DNS record, verify that it has
AAAA but no public A answer, request it with an IPv6-capable client, and inspect task ENIs
to confirm they have no private IPv4 address.

## Cleanup

```shell
terraform destroy
```

With the default `manage_account_setting = false`, this removes only the resources this
pattern created and leaves the account-wide `dualStackIPv6` setting untouched (disable it
separately with `aws ecs put-account-setting-default --name dualStackIPv6 --value disabled`
if no other workload needs it). If you deployed with `manage_account_setting = true`,
`terraform destroy` also disables `dualStackIPv6`.
