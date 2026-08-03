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

> **Note on boot-time image builds:** the Triton container image used by this example is built locally on the instance at boot (see `user_data` in `main.tf`). The ECS agent is intentionally stopped during the build and started afterwards, so ECS cannot place the task on the instance before the image exists. This means every new instance - including instances launched by an ASG instance refresh or scale-out - takes several extra minutes to become available while the image builds, and an instance refresh will temporarily reduce capacity during that window. For production use, publish the image to a registry (for example Amazon ECR) instead of building it at boot.

## Example: Running TinyLlama/TinyLlama-1.1B-Chat-v1.0

Once the cluster and services are deployed, run the request from a host with network access to the VPC and use the internal load balancer DNS name output by Terraform. It can take several minutes for the Triton task to start; if the following command returns 5xx errors, the task might not have started yet.

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

## Cost

This example creates billable AWS resources. Review `terraform plan`, use a sandbox account, and avoid leaving the stack deployed when it is not in use. NAT gateways, load balancers, databases, and accelerated instances are common cost drivers where present.

## Quotas

Confirm that the target Region has sufficient ECS task, elastic network interface, load balancer, and any workload-specific service quotas before deployment. EC2 examples also require available capacity for the selected instance types.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review `terraform plan` before applying. After deployment, use the functional check described above and inspect ECS service events and CloudWatch Logs for task failures.

## Cleanup

Run `terraform destroy` from this example directory. Remove retained data or separately created secrets only after confirming they are no longer needed.
