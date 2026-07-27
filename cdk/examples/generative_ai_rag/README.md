# Generative AI RAG service

This example deploys a private, load-balanced Fargate web application backed by an
Amazon Bedrock knowledge base. It can create the shared core infrastructure and Bedrock
resources or connect the service to existing infrastructure.

Copy `sample.env` to `.env`, set the account and Region, and review the
`deploy_core_stack` and `deploy_bedrock` flags. Then run:

```shell
python -m pip install -r requirements.txt
cdk bootstrap
cdk diff --all
cdk deploy --all
```

When `deploy_bedrock` is `False`, set `knowledge_base_id` to the exact existing
knowledge-base ID. The task role is scoped to that resource.

The load balancer is internal. Use a client in the VPC, such as an ECS Exec session or a
test instance, to reach it.

## Cost

The main cost drivers are the OpenSearch Serverless collection used by the knowledge
base, Bedrock model requests, Fargate tasks, the Application Load Balancer, and a NAT
gateway when the core stack creates one. CloudWatch Logs and the knowledge-source S3
bucket continue to incur storage charges while retained.

## Quotas

Confirm that the selected Region supports the configured Bedrock embedding and Claude
models. Check Bedrock knowledge-base, OpenSearch Serverless OCU, Fargate task, elastic
network interface, and Application Load Balancer quotas. The account must also have
access to the configured Bedrock models.

## Validation

Run `cdk synth` and `cdk diff --all` before deployment. After deployment, run the
following from a client with VPC network access:

```shell
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names genai-fargate-rag \
  --query 'LoadBalancers[0].DNSName' \
  --output text)
curl -fsS "http://${ALB_DNS}/"
```

Open the application and ask a question covered by `assets/reinvent.txt`. Confirm that
the response is grounded in that data and that the ECS log group receives application
events.

## Cleanup

Destroy the service before its dependencies:

```shell
cdk destroy GenAIRAGService
cdk destroy BedrockStack
cdk destroy CoreInfraStack
```

Skip stacks that this app did not create. The knowledge-source bucket uses the CDK
default retention behavior; empty and delete that bucket separately when its data is no
longer needed.
