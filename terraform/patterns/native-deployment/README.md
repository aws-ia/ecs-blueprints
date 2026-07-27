# Native ECS deployments

This self-contained pattern creates a VPC, ECS cluster, Fargate service, Application Load
Balancer, deployment alarm, and Lambda lifecycle hook. It uses ECS native deployments
instead of CodeDeploy.

The first apply defaults to `ROLLING` so ECS establishes a successful service revision
that later deployments can roll back to. After that apply reaches a steady state, set
`deployment_strategy` to `BLUE_GREEN`, `LINEAR`, or `CANARY` to compare traffic shifting.
`LINEAR` moves 20 percent of traffic every minute:

```shell
terraform init
terraform apply
terraform apply -var='deployment_strategy=CANARY'
```

For traffic-shifting strategies, port 80 is the production listener and port 8080 is the
test listener. Set `test_listener_cidr` to the CIDR of a controlled test runner, VPN, or
bastion; it is intentionally not public by default. CloudWatch alarms monitor both target
groups and roll back failed deployments for every strategy. The ECS deployment circuit
breaker provides an additional rollback signal for `ROLLING` deployments.

Terraform waits for the service to reach a steady state before completing an apply. The
included lifecycle hook is deliberately a no-op contract demonstration: it logs the event
and always returns success. ECS reads the Lambda return payload directly, so the handler
returns the case-sensitive `hookStatus` field. It does not validate endpoints, traffic
weights, or application behavior. Replace it with real smoke or integration checks before
using the pattern for production releases.

## Pause, continue, and rollback

AWS provider 6.56 models Lambda lifecycle hooks but does not yet model the newer
pause-hook target and timeout fields. After a deployment reaches a configured pause point,
operate it with the ECS API:

```shell
aws ecs list-service-deployments \
  --cluster "$(terraform output -raw cluster_name)" \
  --service "$(terraform output -raw service_name)"

aws ecs describe-service-deployments \
  --service-deployment-arns <service-deployment-arn>

aws ecs continue-service-deployment \
  --service-deployment-arn <service-deployment-arn> \
  --hook-id <hook-id> \
  --action CONTINUE
```

Use `--action ROLLBACK` to reject the deployment. The deployment details returned by
`describe-service-deployments` also expose ECS Action Logs. This CLI workflow can be
removed when the provider exposes the pause-hook configuration.

## Cost

This pattern creates one NAT gateway, an Application Load Balancer, Fargate tasks, log
groups, and a Lambda function. Review current regional pricing and destroy the pattern
when the deployment lab is not in use.

## Quotas

Confirm VPC, Fargate task, load balancer, target group, Lambda, and CloudWatch alarm quotas.
Native traffic shifting requires a Region that supports the selected ECS deployment
strategy.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After applying, request `application_url`, update the container image to
trigger a deployment, inspect both listeners, and verify the service deployment and Action
Logs with the commands above.

## Cleanup

Run `terraform destroy` from this directory. Terraform also removes the lifecycle-hook log
group. The hook archive is generated under `.terraform` and is removed with the local
Terraform working directory.
