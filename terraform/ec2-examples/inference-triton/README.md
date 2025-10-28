# Triton inference server in Amazon ECS

This solution blueprint runs a triton server with a vLLM backend on top ECS using a g5.12xlarge instance

## Deployment of TinyLlama/TinyLlama-1.1B-Chat-v1.0

1. Deploy core-infra resources

```shell
cd ./terraform/ec2-examples/core-infra
terraform init
terraform apply -target=module.vpc -target=aws_service_discovery_private_dns_namespace.this
```

2. Deploy this blueprint

```shell
cd ../inference-triton
terraform init
terraform apply
```

## Example: Running TinyLlama/TinyLlama-1.1B-Chat-v1.0

Once the cluster and services are deployed, you can use the load balancer DNS name (output during the deployment) to send requests to the vLLM service. It can take several minutes for the triton task to start, if the following command returns 5xx errors, the task might not have started yet.

```bash
ALB_NAME=$(terraform output -raw load_balancer_dns_name)

curl -X POST http://${ALB_NAME}:8000/v2/models/vllm_model/generate \
-d '{"text_input": "In summary, AWS ECS is", "parameters": {"max_tokens": 200, "temperature": 0}}'

```

Example Response:
```json
{"model_name":"vllm_model","model_version":"1","text_output":"In summary, AWS ECS is a container orchestration service that allows you to manage and scale your containerized applications. It provides a simple and intuitive interface for managing your containerized applications, as well as a range of features to help you manage your infrastructure and scale your applications. AWS ECS is a great choice for developers who want to build and manage containerized applications on AWS."}
```

## Clean up

1. Stop the tasks
```shell
aws ecs update-service --service triton-service \
--desired-count 0 --cluster ecs-demo-triton-inference \
--region us-west-2 --query 'service.serviceName'

sleep 30s
```

2. Destroy this blueprint

```shell
terraform destroy
```

3. Destroy core-infra resources

```shell
cd ../core-infra
terraform destroy

```

## Support

Please open an issue for questions or unexpected behavior
