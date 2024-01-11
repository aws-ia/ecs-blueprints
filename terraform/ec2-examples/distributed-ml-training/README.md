# ECS machine learning distributed training

This solution blueprint creates the infrastructure to run distributed training jobs using a [Ray cluster](https://docs.ray.io/en/latest/cluster/getting-started.html) and [PyTorch](https://pytorch.org/).

![Distributed ML architecture](../../../docs/distributed-ml-training-architecture.png)

By default, this blueprint uses g5.xlarge (with 1 GPU) instances to showcase a multi-node, data parallel distributed training. You can modify this blueprint to use larger instances from the local variable **instance_type_workers** if you need more GPUs. - if you change the instance type, you need to also modify the worker task and service definition memory, CPU and GPUs and the container command parameters. The [training script example](./training_example.py) assumes 2 machines with a single GPU each, but can be changed via the **num_workers** variable.

## Components

* Service discovery: The head node is registered to a private DNS using local zones via cloud map. This allows worker tasks to discover the head task and join the cluster on start up.
* 2 autoscaling groups: One for the head instance and another one for the worker instances
* ECS service definition:
    * Head service: runs singleton processes responsible for cluster management
    * Worker service: runs training jobs
* S3 bucket to store the results

## Deployment

1. Deploy core-infra resources

```shell
cd ./terraform/ec2-examples/core-infra
terraform init
terraform apply -target=module.vpc -target=aws_service_discovery_private_dns_namespace.this

```

2. Deploy this blueprint

```shell
cd ../distributed-ml-training
terraform init
terraform apply
```

## Example: training the resnet model with the FashionMNIST dataset

Once the cluster is deployed, you can connect to the EC2 instance running the head container using SSM, and open a bash shell in the container from there. This is only for demonstration purposes - Using notebooks with [SageMaker](https://aws.amazon.com/sagemaker/) or [Cloud 9](https://aws.amazon.com/cloud9/) provide a better user experience to run training jobs in python than using the bash shell

1. Connect to the instance
```bash
HEAD_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=ecs-demo-distributed-ml-training-head' \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)

aws ssm start-session --target $HEAD_INSTANCE_ID
```

2. Connect to the container

Due to the size of the container images, it might take several minutes until the containers reach a running state. The following command will fail if the contains is not running.

```
CONTAINER_ID=$(sudo docker ps -qf "name=.*-rayhead-.*")
sudo docker exec -it $CONTAINER_ID bash
```

3. Inside the container shell, check the cluster status. 3 nodes should be listed as healthy with 2.0 GPUs available
```bash
ray status
```

Example output:

```
======== Autoscaler status: 2024-01-11 07:19:06.991162 ========
Node status
---------------------------------------------------------------
Healthy:
 1 node_a3d74b6d5089c52f9848c1529349ba5c4966edaa633374b0566c7d69
 1 node_a5a1aa596068c73e17e029ca221bfad7a7b0085a0273da3c7ad86096
 1 node_3ae0c0cabb682158fef418bbabdf2ea63820e8b68e4ae2f4b24c8e66
Pending:
 (no pending nodes)
Recent failures:
 (no failures)

(...)

Resources
---------------------------------------------------------------
Usage:
 0.0/6.0 CPU
 0.0/2.0 GPU
 0B/38.00GiB memory
 0B/11.87GiB object_store_memory

Demands:
 (no resource demands)

```

4. Run the [training script example](./training_example.py) - you can look at the comments inside the python script to learn more about each step.
A bucket is created as part of the terraform plan (Bucket ARN is printed as output). Make sure to add the name of that bucket (starts with "dt-results-") as argument of the training_example.py script

```bash
export RAY_DEDUP_LOGS=0 # Makes the logs verbose per each process in the training
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-ml-training/training_example.py
python training_example.py YOUR_BUCKET_NAME
```

## Clean up

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
