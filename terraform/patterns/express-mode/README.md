# ECS Express Mode

This self-contained pattern creates one VPC and ECS cluster. The default deployment
demonstrates the image-to-HTTPS Express Mode path:

1. `quick_start` turns a container image into an autoscaled HTTPS endpoint.

The optional `custom` variant supplies a Fargate task definition with explicit CPU and
memory limits, a container health check, and a FireLens log-router sidecar.

```shell
terraform init
terraform apply

terraform output -raw quick_start_url
terraform output -json quick_start_ingress_paths
```

Use `quick_start_ingress_paths` to determine whether each endpoint is `PUBLIC` or
`PRIVATE`. Request private endpoints from a client with network access to the VPC.

Express service names cannot be reused immediately after deletion, so a stable random
suffix is stored in Terraform state.

AWS provider 6.56 and the ECS module expose the image-based resource but do not yet expose
`TaskDefinitionArn`. The custom variant therefore creates only the
`AWS::ECS::ExpressGatewayService` resource through a Terraform-managed CloudFormation
stack. Remove that compatibility layer when the Terraform provider adds the field; the
task definition, roles, network, and logs remain regular Terraform resources.

The custom variant is disabled by default to keep the baseline deployment focused on the
image-to-HTTPS path. Enable it to deploy the custom task definition:

```shell
terraform apply -var='enable_custom_task_definition=true'
terraform output -raw custom_task_definition_url
```

The `Main` container is intentionally the first serialized container definition. Current
Express Mode custom-task provisioning does not attach the managed load balancer when a
sidecar precedes `Main`.

## Cost

The default creates one NAT gateway, one Express Gateway service and its managed load
balancer, Fargate tasks, and CloudWatch logs. Enabling the custom variant adds a second
service, load balancer, task, and log group.

## Quotas

Confirm VPC, Fargate task, Express Gateway service, load balancer, CloudFormation stack,
and CloudWatch Logs quotas. Express Mode must be available in the selected Region.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After applying, request each enabled HTTPS output from clients matching
its access type and verify the autoscaling target. When the custom variant is enabled,
confirm it reaches one requested task and writes `router` and `web` streams before
considering the deployment successful.

## Cleanup

Record the generated prefix, then destroy the pattern:

```shell
resource_prefix=$(terraform output -raw resource_name_prefix)
terraform destroy
```

Wait for each enabled Express service and the optional Terraform-managed CloudFormation
stack to finish deleting before reusing the same Terraform state. Express Gateway may
retain a service-managed rollback alarm after the service is gone. Audit that exact prefix
and delete any remaining alarm:

```shell
aws cloudwatch describe-alarms \
  --alarm-name-prefix "${resource_prefix}/" \
  --query 'MetricAlarms[].AlarmName' \
  --output text

aws cloudwatch delete-alarms --alarm-names <REMAINING_ALARM_NAME>
```

If the Terraform-managed CloudFormation stack reaches `DELETE_FAILED` after its Express
service is already absent,
retry that stack deletion and then rerun Terraform:

```shell
aws cloudformation delete-stack \
  --stack-name "${resource_prefix}-custom-express"
aws cloudformation wait stack-delete-complete \
  --stack-name "${resource_prefix}-custom-express"
terraform destroy
```
