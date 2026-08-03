# ECS Managed Instances service

This self-contained pattern creates a VPC, ECS cluster, Managed Instances capacity
provider, load-balanced web service, and Managed Daemon. ECS selects, launches, patches,
and drains the EC2 capacity; there is no Auto Scaling group or launch template to manage.

## Prerequisites

Managed Instances does not expose per-volume encryption settings, so EBS encryption by
default must already be enabled in the deployment Region. Check the account setting:

```shell
region=us-west-2
aws ec2 get-ebs-encryption-by-default \
  --region "$region" \
  --query EbsEncryptionByDefault \
  --output text
```

The expected result is `True`. If it is `False`, enable it before applying:

```shell
aws ec2 enable-ebs-encryption-by-default --region "$region"
```

This is a regional, account-wide setting for new EBS volumes and snapshot copies; it does
not change existing volumes or snapshots. Apply it through your account baseline when
possible. This pattern checks the setting but does not manage it, because destroying the
pattern must not disable an account-wide security control.

```shell
terraform init
terraform apply
```

The default capacity is on demand. To use Spot and retain idle instances for ten minutes:

```shell
terraform apply \
  -var='capacity_option_type=SPOT' \
  -var='scale_in_after_seconds=600'
```

Set `require_instance_store=true` to constrain selection to current-generation instances
with at least 20 GB of local SSD. The Managed Daemon writes a heartbeat from every managed
node to `/aws/ecs/<name>/managed-daemon`; replace it with a security, telemetry, or storage
agent that must run once per node.

AWS provider 6.56 does not yet expose Managed Instances capacity-reservation preferences,
GPU auto-repair, or repair policy fields. Do not encode those options through `local-exec`;
add them to the capacity provider when the provider schema supports them. Accelerated
compute is intentionally kept out of this baseline pattern because instance, driver, and
model requirements need their own deployment tests. This pattern accepts scale-in delays
from 0 through 3600 seconds; it intentionally excludes `-1` because disabling scale-in
would prevent a complete Terraform destroy.

## Security

The pattern uses dedicated infrastructure and node roles modeled on the AWS managed
policies. `iam:PassRole` is restricted to the generated node role and EC2. Security groups
admit application traffic only from the load balancer, and tasks run in private subnets.

The pattern stops at plan time when the regional EBS encryption-by-default prerequisite
is not satisfied.

## Cost

This pattern creates one NAT gateway, an Application Load Balancer, EC2 capacity selected
by Managed Instances, EBS storage, and CloudWatch logs. Managed Instances pricing and Spot
interruptions vary by Region and selected instance type.

## Quotas

Confirm EC2 On-Demand or Spot vCPU, VPC, load balancer, ECS Managed Instances capacity
provider, and Managed Daemon quotas. Spot also needs the EC2 Spot service-linked role; the
infrastructure policy can create it if absent.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After applying, request `application_url`, confirm container instances
are marked managed in the ECS console, and verify one daemon heartbeat stream per node.
Confirm the managed-node EBS volumes are encrypted. Test scale-in delay by scaling the
service to zero and observing the instance lifecycle.

## Cleanup

Run `terraform destroy` from this directory. Terraform keeps VPC egress available and waits
for the configured scale-in delay plus one minute before deleting the capacity provider, so
cleanup can take several minutes while ECS drains and terminates managed capacity.
