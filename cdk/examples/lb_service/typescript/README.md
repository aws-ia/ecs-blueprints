# ECS load-balanced web service (TypeScript CDK)

This is the TypeScript counterpart of the Python [`lb_service`](../) example and the
recommended starting point for TypeScript CDK users. It is a single self-contained
stack: a VPC (2 AZs, one NAT gateway), an ECS cluster, and a public-facing
`ApplicationLoadBalancedFargateService` running three copies of the
`ecsdemo-frontend` demo container. It creates every resource it uses — no shared
`core_infra` stack, no `.env` file, and no lookups of existing resources.

Compared with the Python example, this app intentionally omits the private companion
backend, Cloud Map namespace, and autoscaling so that the template stays as small as
possible for a first deployment. The demo frontend renders "no backend found" for the
backend panel, which is expected.

## Deployment

Prerequisites: Node.js 22 and AWS credentials for a sandbox account (see
[AWS authentication](../../../../docs/authentication.md)).

```bash
cd cdk/examples/lb_service/typescript
npm ci
```

The stack picks up the account and Region from your CLI configuration via
`CDK_DEFAULT_ACCOUNT` / `CDK_DEFAULT_REGION` — no `.env` file is needed. If the
account/Region has never been bootstrapped for CDK, run this once:

```bash
npx cdk bootstrap
```

Then deploy:

```bash
npx cdk deploy
```

The `ApplicationUrl` output is the public HTTP endpoint. The load balancer accepts
traffic on port 80 and health-checks the container on `/`. For production use, add an
ACM certificate, redirect HTTP to HTTPS, and consider AWS WAF.

## Cost

The NAT gateway and the Application Load Balancer dominate cost and bill hourly while
idle; the three Fargate tasks (256 CPU / 512 MiB each) and CloudWatch logs add the
rest. The stack is suitable for short-lived evaluation — deploy, test, and destroy in
the same session rather than leaving it running.

## Quotas

Confirm the target Region has headroom for: VPCs per Region, Elastic IP addresses
(one for the NAT gateway), NAT gateways per AZ, Application Load Balancers, target
groups, Fargate on-demand vCPU, and elastic network interfaces.

## Validation

Static checks (no AWS credentials required):

```bash
npm run build   # compile TypeScript
npm test        # assertions against the synthesized template
npx cdk synth   # render the CloudFormation template
```

With credentials, run `npx cdk diff` before deploying. After deployment, the
functional check is an HTTP request to the load balancer:

```bash
URL=$(aws cloudformation describe-stacks --stack-name LoadBalancedServiceTs \
  --query "Stacks[0].Outputs[?OutputKey=='ApplicationUrl'].OutputValue | [0]" \
  --output text)
curl -sf "$URL" | grep -i "ecsdemo"
```

Also confirm all three targets are healthy in the target group and that the ECS
service shows three running tasks.

## Cleanup

```bash
npx cdk destroy
```

The VPC, cluster, service, and load balancer are deleted as one stack; there are no
ordering constraints. The service's CloudWatch log group is retained by default —
delete `LoadBalancedServiceTs-*` log groups in the CloudWatch console if you do not
need the logs.
