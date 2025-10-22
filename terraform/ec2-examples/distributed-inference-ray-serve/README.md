# ECS distributed inference using Ray Serve

This solution blueprint creates the infrastructure to run distributed inference jobs using a [Ray cluster](https://docs.ray.io/en/latest/cluster/getting-started.html) with Ray Serve

## Components

* Service discovery: The head node is registered to a private DNS using local zones via cloud map. This allows worker tasks to discover the head task and join the cluster on start up.
* 2 EC2 capacity providers: One for the head instance and another one for the worker instances
* ECS services:
  * Head service: runs singleton processes responsible for cluster management along with training and inference jobs
  * Worker service: runs training and inference jobs

## Deployment

1. Deploy core-infra resources

```shell
cd ./terraform/ec2-examples/core-infra
terraform init
terraform apply -target=module.vpc -target=aws_service_discovery_private_dns_namespace.this
```

2. Deploy this blueprint

```shell
cd ../distributed-inference-ray-serve
terraform init
terraform apply
```

Once the cluster is deployed and tasks running, you can connect to the head task via ECS connect. This is only for demonstration purposes - Using notebooks with [SageMaker](https://aws.amazon.com/sagemaker/) or an automated deployment pipeline provide a better user experience to interact with ray clusters in development and production environments.

The tasks can take several minutes to deploy, and the following steps will fail if they are not running

3. Connect to the head container.

```bash
TASK_ID=$(aws ecs list-tasks --cluster ecs-demo-distributed-ml-inference --service-name distributed_ml_inference_head_service --region us-west-2 --output text | awk -F'/' '{print $NF}')

aws ecs execute-command --region us-west-2 --cluster ecs-demo-distributed-ml-inference --task $TASK_ID --container ray_head --command 'bash -c "su ray"' --interactive
```

5. Check the cluster status. 3 nodes should be listed as healthy with a total of 12.0 GPUs available - If you do not see 12.0 GPUs, the workers have not started yet.

```bash
ray status
```

Example output:

```======== Autoscaler status: (...) ========
Node status
---------------------------------------------------------------
Active:
 1 node_4cb4db2f7c8fd695f3824cba63bef63174ed32e597c5201cd58518c4
 1 node_c1a759699fc01ab632b301050e0df75941746bc2fd24b7d898beb1be
 1 node_26b200813afe3dce69d564464ca3817006be363463d19dcb2a279205
Pending:
 (no pending nodes)
Recent failures:
 (no failures)

Resources
---------------------------------------------------------------
Total Usage:
 0.0/30.0 CPU
 0.0/12.0 GPU
 0B/540.00GiB memory
 0B/38.00GiB object_store_memory

Total Constraints:
 (no request_resources() constraints)
Total Demands:
 (no resource demands)

```

## Example 1: Fractional GPU using T5 small for translation from english to french

1. Download fractional inference scripts. 

```bash
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/translator_t5_small.py
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/fractional_gpu.yaml
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/test_translator.py
```

2. Use ray serve to deploy 28 instances of the t5 model using 0.5 GPUs per each one. This loads 2 model instances per physical NVIDIA A10 chip

```bash
serve deploy fractional_gpu.yaml
```

3. Verify deployment. It can take several minutes for the deployment to reach HEALTHY state

```bash
serve status
```

Example output:

```bash
proxies:
  26b200813afe3dce69d564464ca3817006be363463d19dcb2a279205: HEALTHY
  4cb4db2f7c8fd695f3824cba63bef63174ed32e597c5201cd58518c4: HEALTHY
  c1a759699fc01ab632b301050e0df75941746bc2fd24b7d898beb1be: HEALTHY
applications:
  translator:
    status: RUNNING
    message: ''
    last_deployed_time_s: 1759186094.041096
    deployments:
      Translator:
        status: HEALTHY
        status_trigger: CONFIG_UPDATE_COMPLETED
        replica_states:
          RUNNING: 24
        message: ''
target_capacity: null
```

4. Verify fractional GPU

```bash
nvidia-smi
```

Example output

```bash
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.172.08             Driver Version: 570.172.08     CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA A10G                    On  |   00000000:00:1B.0 Off |                    0 |
|  0%   31C    P0             57W /  300W |    1062MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   1  NVIDIA A10G                    On  |   00000000:00:1C.0 Off |                    0 |
|  0%   30C    P0             60W /  300W |     986MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   2  NVIDIA A10G                    On  |   00000000:00:1D.0 Off |                    0 |
|  0%   29C    P0             55W /  300W |     986MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   3  NVIDIA A10G                    On  |   00000000:00:1E.0 Off |                    0 |
|  0%   30C    P0             57W /  300W |     986MiB /  23028MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A            3713      C   ...Replica:translator:Translator        562MiB |
|    0   N/A  N/A            3714      C   ...Replica:translator:Translator        486MiB |
|    1   N/A  N/A           17156      C   ...Replica:translator:Translator        486MiB |
|    1   N/A  N/A           17157      C   ...Replica:translator:Translator        486MiB |
|    2   N/A  N/A           17158      C   ...Replica:translator:Translator        486MiB |
|    2   N/A  N/A           17159      C   ...Replica:translator:Translator        486MiB |
|    3   N/A  N/A           17160      C   ...Replica:translator:Translator        486MiB |
|    3   N/A  N/A           17161      C   ...Replica:translator:Translator        486MiB |
+-----------------------------------------------------------------------------------------+

```

Note that two copies of the model are deployed in each GPU index. Additional copies are deployed in the other machines that are part of the cluster. You can verify the deployment of the model in other nodes using the GPU memory utilization metric available at the [distributed-inference-ray-serve cloudwatch dashboard](https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards/dashboard/distributed-inference-ray-serve) that was created with terraform. It can take several minutes for metrics to be reflected in cloudwatch

5. Test the model

```bash
python test_translator.py "Hello ECS!"
```

Example output:

```bash
Bonjour ECS!
```

Congratulations! You have succesfully deployed a model using fractional GPUs in ECS

6. Before moving to the next section, delete the T5 model from ray serve

```bash
serve shutdown -y
```

## Example 2: Tensor parallelism deployment with Llama 3.1 7B

Tensor parallelism is a technique that allows for a model to be deployed in multiple GPUs within the same VM instance or ECS task, and it is meant to be used when the model can't fit in the memory within a single GPU. In this step, you will deploy a Llama 3.1 7B accross the 4 GPUs available in a g5.12xlarge instance

1. Download Tensor parallelism inference files

```bash
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/serve_llama.py
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/deploy_llama.yaml
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/test_llama.py
```

2. Deploy with ray serve

```bash
serve deploy deploy_llama.yaml
```

It can take several minutes for the deployment to reach a HEALTHY state. You can check status with this command

```
serve status
```

Example output

```
proxies:
  fdeb8fb5bb67b836e5d8289300b20d977be1a769c8179701e211bb0b: HEALTHY
  257c4e28a32ee2ea1a96d9b2956ce517aba8c4b06a0d8f4ddcaa86e7: HEALTHY
  adaff76c5543b7c394c5509704251ec9bd372cc5c10b94a914b110b2: HEALTHY
applications:
  app1:
    status: RUNNING
    message: ''
    last_deployed_time_s: 1759271090.4104083
    deployments:
      LLMServer:my-llama-3_1-8b:
        status: HEALTHY
        status_trigger: CONFIG_UPDATE_COMPLETED
        replica_states:
          RUNNING: 1
        message: ''
      LLMRouter:
        status: HEALTHY
        status_trigger: CONFIG_UPDATE_COMPLETED
        replica_states:
          RUNNING: 2
        message: ''
target_capacity: null
```

3. Test model

```
python test_llama.py "What is AWS ECS? Provide a short answer"
```

Example output

```
AWS ECS (Elastic Container Service) is a container orchestration service offered by Amazon Web Services (AWS). It allows users to run, stop, and manage containers on a cluster of EC2 instances. ECS provides a managed way to deploy and manage containerized applications, making it easier to scale and manage containerized workloads.
```

4. Verify the deployment of the model in one of the instances using the GPU memory utilization metric available at the [distributed-inference-ray-serve cloudwatch dashboard](https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards/dashboard/distributed-inference-ray-serve) that was created with terraform. Tensor parallelism deploys the model accross multiple GPUs in a single node, it is expected for a single EC2 instance to show increased GPU memory in this example. It can take a couple of minutes for the metrics to appear.

5. Before moving to the next section, delete the model from ray serve

```bash
serve shutdown -y
```

## Example 3: Llama 3.1 80B deployment using pipeline and tensor parallelism 

While tensor parallelism allows a model to deploy into multiple GPUs in the same machine, pipeline parallelism implements distributed inference accross different nodes, such as EC2 instances or ECS tasks. Using these techniques, you can implement distributed inference with multi-GPU and multi-node environments

1. Download pipeline parallelism inference files:

```bash
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/serve_llama_pp.py
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/deploy_llama_pp.yaml
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-inference-ray-serve/test_llama.py
```

2. Deploy with ray serve

```bash
serve deploy deploy_llama_pp.yaml
```

It can take several minutes for the deployment to reach a HEALTHY state. You can check status with this command

```
serve status
```

Example output

```
proxies:
  fdeb8fb5bb67b836e5d8289300b20d977be1a769c8179701e211bb0b: HEALTHY
  257c4e28a32ee2ea1a96d9b2956ce517aba8c4b06a0d8f4ddcaa86e7: HEALTHY
  adaff76c5543b7c394c5509704251ec9bd372cc5c10b94a914b110b2: HEALTHY
applications:
  app1:
    status: RUNNING
    message: ''
    last_deployed_time_s: 1759271090.4104083
    deployments:
      LLMServer:my-llama-3_1-8b:
        status: HEALTHY
        status_trigger: CONFIG_UPDATE_COMPLETED
        replica_states:
          RUNNING: 1
        message: ''
      LLMRouter:
        status: HEALTHY
        status_trigger: CONFIG_UPDATE_COMPLETED
        replica_states:
          RUNNING: 2
        message: ''
target_capacity: null
```

3. Test model

```
python test_llama.py "What is AWS ECS?"
```

Example output

```
AWS ECS (Amazon Elastic Container Service) is a container orchestration service provided by Amazon Web Services (AWS). It allows users to run, stop, and manage containerized applications across a cluster of EC2 instances. ECS enables you to easily deploy, manage, and scale your containerized applications.
(...)
```

4. Verify the deployment of the model in the three instances using the GPU memory utilization metric available at the [distributed-inference-ray-serve cloudwatch dashboard](https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards/dashboard/distributed-inference-ray-serve) that was created with terraform. Because we are now loading the model accross all three nodes and all their GPUs, memory utilization increases in all instances.

5. Before moving to the next section, delete the model from ray serve

```bash
serve shutdown -y
```

## Clean up

1. Stop ECS tasks and wait for the status to be propagated via ECS. 

```shell
aws ecs update-service --service distributed_ml_inference_worker_service \
--desired-count 0 --cluster ecs-demo-distributed-ml-inference \
--region us-west-2 --query 'service.serviceName'

aws ecs update-service --service distributed_ml_inference_head_service \
--desired-count 0 --cluster ecs-demo-distributed-ml-inference \
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
