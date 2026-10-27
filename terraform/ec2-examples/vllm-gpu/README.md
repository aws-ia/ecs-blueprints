# ECS inference using vLLM

This solution blueprint creates the infrastructure to run models in multiple GPUs using tensor parallelism within a single task with vLLM

## Components

* ECS service:
  * vllm service: runs an inference task of unsloth/Meta-Llama-3.1-8B-Instruct in 4 GPUs within a g5.12xlarge instance

> **Model provenance:** this example downloads model weights from `unsloth/Meta-Llama-3.1-8B-Instruct`, an unofficial Hugging Face mirror of Meta's Llama 3.1 8B Instruct weights. The mirror is used because the official `meta-llama/Llama-3.1-8B-Instruct` repository is gated and requires accepting Meta's license. To use the official repository instead, request access on Hugging Face, change the `--model` argument in `main.tf` to `meta-llama/Llama-3.1-8B-Instruct`, and pass a Hugging Face token to the container (for example an `HF_TOKEN` environment variable sourced from AWS Secrets Manager via the task definition `secrets` block - avoid hardcoding the token in Terraform).

## Deployment

1. Deploy core-infra resources

```shell
cd ./terraform/ec2-examples/core-infra
terraform init
terraform apply -target=module.vpc -target=aws_service_discovery_private_dns_namespace.this
```

2. Deploy this blueprint

```shell
cd ../vllm-gpu
terraform init
terraform apply
```

Once the task is running, you can open a shell with ECS connect. This is only for demonstration purposes - in production, an ALB can be used to make requests to containers in ECS.

The task can take several minutes to deploy, and the following steps will fail if they are not running

3. Connect to the vllm container.

```bash
TASK_ID=$(aws ecs list-tasks --cluster ecs-demo-vllm-gpu --service-name vllm_inference_service --region us-west-2 --output text | awk -F'/' '{print $NF}')

aws ecs execute-command --region us-west-2 --cluster ecs-demo-vllm-gpu --task $TASK_ID --container vllm --command 'bash' --interactive
```

4. Check the GPU memory utilization and processes. All GPUs should have a process running

```bash
nvidia-smi
```

Example output:

```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.65.06              Driver Version: 580.65.06      CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA A10G                    On  |   00000000:00:1B.0 Off |                    0 |
|  0%   36C    P0             62W /  300W |   21963MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   1  NVIDIA A10G                    On  |   00000000:00:1C.0 Off |                    0 |
|  0%   36C    P0             62W /  300W |   21965MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   2  NVIDIA A10G                    On  |   00000000:00:1D.0 Off |                    0 |
|  0%   36C    P0             64W /  300W |   21965MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   3  NVIDIA A10G                    On  |   00000000:00:1E.0 Off |                    0 |
|  0%   36C    P0             62W /  300W |   21965MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A             385      C   VLLM::Worker_TP0                      21954MiB |
|    1   N/A  N/A             386      C   VLLM::Worker_TP1                      21956MiB |
|    2   N/A  N/A             387      C   VLLM::Worker_TP2                      21956MiB |
|    3   N/A  N/A             388      C   VLLM::Worker_TP3                      21956MiB |
+-----------------------------------------------------------------------------------------+
```

5. Verify the models available

```bash
curl http://localhost:8000/v1/models
```

Example output
```
{"object":"list","data":[{"id":"unsloth/Meta-Llama-3.1-8B-Instruct","object":"model","created":1759434353,"owned_by":"vllm","root":"unsloth/Meta-Llama-3.1-8B-Instruct","parent":null,"max_model_len":131072,"permission":[{"id":"modelperm-89cb4570db084669b1adbeedd944bb7b","object":"model_permission","created":1759434353,"allow_create_engine":false,"allow_sampling":true,"allow_logprobs":true,"allow_search_indices":false,"allow_view":true,"allow_fine_tuning":false,"organization":"*","group":null,"is_blocking":false}]}]}
```

6. Make an inference request

```
curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "unsloth/Meta-Llama-3.1-8B-Instruct",
        "prompt": "What is AWS ECS?",
        "max_tokens": 100,
        "temperature": 0
    }'
```

Example output

```
{"id":"cmpl-a800137ba92242cf8cb5553d776d7edb","object":"text_completion","created":1759434425,"model":"unsloth/Meta-Llama-3.1-8B-Instruct","choices":[{"index":0,"text":" Amazon Web Services (AWS) Elastic Container Service (ECS) is a container orchestration service that allows you to run, stop, and manage containers on a cluster. ECS is a managed service that makes it easy to deploy, manage, and scale containerized applications. It provides a highly scalable, secure, and high-performance environment for running containers.\n\nHere are some key features of AWS ECS:\n\n1.  **Container Orchestration**: ECS automates the deployment, scaling, and management of containers","logprobs":null,"finish_reason":"length","stop_reason":null,"token_ids":null,"prompt_logprobs":null,"prompt_token_ids":null}],"service_tier":null,"system_fingerprint":null,"usage":{"prompt_tokens":6,"total_tokens":106,"completion_tokens":100,"prompt_tokens_details":null},"kv_transfer_params":null}
```

7. You can check the GPU utilzation as you make requests using the [vllm-inference cloudwatch dashboard](https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards/dashboard/vllm-inference) that was created with terraform

8. Logs are sent to cloudwatch by default. These can be accessed via the task view, and selecting the Logs tab.

## Clean up

1. Stop ECS tasks and wait for the status to be propagated with ECS.

```shell
aws ecs update-service --service vllm_inference_service \
--desired-count 0 --cluster ecs-demo-vllm-gpu \
--region us-west-2 --query 'service.serviceName'

sleep 30s
```

1. Destroy this blueprint

```shell
terraform destroy
```

1. Destroy core-infra resources

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
