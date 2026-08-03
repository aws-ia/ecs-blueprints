# ECS backend service with service discovery

This self-contained example creates its own VPC, ECS cluster, private Cloud Map namespace,
and Fargate backend service. It no longer requires a separate `core-infra` deployment or
discovers resources by fixed names and tags.

## Existing state

This self-contained topology intentionally changes the cluster and VPC used by releases
that predate the v7 migration. Deploy it with a new backend key or workspace, validate the
replacement, move callers to its new private endpoint, and then retire the old service.
Do not apply it to an existing shared-infrastructure state as a routine in-place upgrade.
See the [v7 migration guide](../../../docs/terraform-v7-migration.md) for state backup and
plan review requirements.

```shell
terraform init
terraform plan
terraform apply
```

The service is available only inside its VPC at the
`service_discovery_endpoint` output. Its security group allows port 3000 from the VPC CIDR
and does not expose the service to the internet. Set `name` to deploy another isolated copy
in the same account and Region.

Use ECS Exec from a task in the VPC or launch a controlled test client to request the
private endpoint. The [load-balanced service example](../lb-service/README.md) includes its
own companion backend and can be deployed independently.

## Cost

This example creates one NAT gateway, three Fargate tasks, Cloud Map resources, and
CloudWatch logs. Review current regional pricing and destroy the stack when it is not in
use.

## Quotas

Confirm VPC, NAT gateway, Fargate task, elastic network interface, Cloud Map namespace,
and service quotas in the selected Region.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After deployment, request `service_discovery_endpoint` from a VPC client
and inspect ECS service events and CloudWatch Logs for task failures.

## Cleanup

Run `terraform destroy` from this directory. Networking, cluster, namespace, and service
are owned by the same Terraform state and are removed together.
