# ECS Express Mode

This self-contained CDK app creates a VPC and ECS cluster. By default it turns an image,
port, and CPU/memory settings into an autoscaled HTTPS endpoint.

An opt-in custom Fargate task definition adds explicit container limits, a health check,
and a FireLens log-router sidecar.

AWS CDK 2.262.1 includes the `CfnExpressGatewayService` L1 construct. Networking, IAM,
logs, the custom task definition, and the Express resources all use typed CDK constructs.

From the `cdk` directory:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt -r requirements-dev.txt
cd examples/express_mode
cdk synth
cdk deploy --require-approval never
```

The default stack outputs `BasicEndpoint` and `BasicServiceArn`. Check the service's
ingress access type and request private endpoints from a client with access to the VPC.
CloudFormation generates service names so a destroy followed by a redeploy does not reuse
an Express service name.

The custom variant is disabled by default to keep the baseline deployment focused on the
image-to-HTTPS path. Enable it to deploy the custom task definition:

```bash
cdk deploy -c enableCustomTaskDefinition=true --require-approval never
```

The `Main` container is intentionally added before the FireLens sidecar and has an explicit
`START` dependency on the router. This preserves `Main` as the first registered container
definition. Current Express Mode custom-task provisioning does not attach the managed load
balancer when a sidecar precedes `Main`.

That deployment also outputs `CustomEndpoint` and `CustomServiceArn`.

## Cost

The default creates one NAT gateway, one Express Gateway service and its managed load
balancer, Fargate tasks, and CloudWatch logs. The custom opt-in adds a second service,
load balancer, task, and log group.

## Quotas

Confirm VPC, Fargate task, Express Gateway service, load balancer, IAM role, and CloudWatch
Logs quotas. Express Mode must be available in the target Region.

## Validation

Run `cdk synth` and `cdk diff` before deployment. After deploying, request both HTTPS
outputs from clients matching their ingress access types and inspect their autoscaling
targets. When the custom variant is enabled, confirm it reaches one requested task and
writes router and application streams before considering the deployment successful.

## Cleanup

Run `cdk destroy` with the same context used for deployment. Wait for each enabled
Express service and managed load balancer to finish deleting before redeploying. If an
Express-managed rollback alarm remains, derive the service name from the corresponding
`ServiceArn` output, audit CloudWatch alarms for that exact name, and delete only the
orphaned alarm.
