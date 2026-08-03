# ECS frontend service with an Application Load Balancer

This self-contained CDK app creates one stack containing its VPC, ECS cluster, Cloud Map
namespace, public frontend, private companion backend, and Application Load Balancer. It
does not import the sibling `core_infra` example or look up existing resources.

A TypeScript version of this example (frontend only, no companion backend) lives in
[`typescript/`](./typescript/).

Create `.env` with the target account and Region:

```bash
export AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:=us-west-2}

sed -e "s/<ACCOUNT_NUMBER>/$AWS_ACCOUNT/g" \
  -e "s/<REGION>/$AWS_REGION/g" sample.env > .env
```

Then synthesize and deploy:

```bash
cdk synth
cdk deploy --require-approval never
```

The load balancer accepts public HTTP traffic on port 80. Only the frontend task security
group can reach the backend on port 3000. The frontend resolves the backend through
`backend.default.ecs-blueprint-lb-service.local`.

For production use, add an ACM certificate, redirect HTTP to HTTPS, and consider AWS WAF.

## Cost

This app creates one NAT gateway, an Application Load Balancer, Fargate tasks, Cloud Map
resources, and CloudWatch logs. Review current regional pricing and do not leave the stack
running when it is not in use.

## Quotas

Confirm VPC, NAT gateway, Fargate task, elastic network interface, load balancer, target
group, and Cloud Map quotas in the target Region.

## Validation

Run `cdk synth` and `cdk diff` before deployment. After deployment, request the
`ApplicationUrl` output, confirm targets are healthy, and inspect both ECS services and
their CloudWatch log groups.

## Cleanup

Run `cdk destroy` from this directory. Networking, cluster, namespace, frontend, and
backend are deleted as one stack.
