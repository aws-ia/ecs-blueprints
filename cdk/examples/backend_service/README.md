# ECS backend service with service discovery

This self-contained CDK app creates one stack containing its VPC, ECS cluster, private
Cloud Map namespace, and Fargate backend service. It does not import the sibling
`core_infra` example or look up existing resources.

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

The service is reachable only from its VPC at the `BackendEndpoint` output. Its security
group allows port 3000 from the VPC CIDR and does not expose the service to the internet.
Use ECS Exec or a controlled VPC test client for functional checks.

## Cost

This app creates one NAT gateway, Fargate tasks, Cloud Map resources, and CloudWatch logs.
Review current regional pricing and do not leave the stack running when it is not in use.

## Quotas

Confirm VPC, NAT gateway, Fargate task, elastic network interface, Cloud Map namespace,
and service quotas in the target Region.

## Validation

Run `cdk synth` and `cdk diff` before deployment. After deployment, request the private
`BackendEndpoint` from a VPC client and inspect ECS service events and CloudWatch Logs.

## Cleanup

Run `cdk destroy` from this directory. Networking, cluster, namespace, and service are
deleted as one stack.
