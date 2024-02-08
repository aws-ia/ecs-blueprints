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
  --filters 'Name=tag:Name,Values=ecs-demo-distributed-ml-training-head' 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[0].InstanceId' --output text --region us-west-2
)

aws ssm start-session --target $HEAD_INSTANCE_ID --region us-west-2
```

2. Connect to the container

Due to the size of the container images, it might take several minutes until the containers reach a running state. The following command will fail if the container is not running.

```
CONTAINER_ID=$(sudo docker ps -qf "name=.*-rayhead-.*")
sudo docker exec -it $CONTAINER_ID bash
```

3. Inside the container shell, check the cluster status. 3 nodes should be listed as healthy with 2.0 GPUs available - If you do not see 2.0 GPUs, the workers have not started yet.

```bash
ray status
```

Example output:

```
(...)
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

4. Run the [training script example](./training_example.py) - It uses distributed data parallel to split the data between GPUs. You can look at the comments inside the python script to learn more about each step. A bucket is created as part of the terraform plan (Bucket name is printed as output). Make sure to add the name of that bucket (starts with "dt-results-") as argument of the training_example.py script

```bash
export RAY_DEDUP_LOGS=0 # Makes the logs verbose per each process in the training
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-ml-training/training_example.py
python training_example.py YOUR_BUCKET_NAME
```

Example output:

```
(...)
Wrapping provided model in DistributedDataParallel.
(...)

(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 0 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.660568237304688]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 0 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.65453052520752]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 1 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.172431230545044]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 1 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.17476797103882]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 2 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 16.807305574417114]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 2 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 16.807661056518555]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 3 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.16184115409851]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 3 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.164414882659912]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 4 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.43423628807068]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 4 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.430140495300293]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 5 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.319995880126953]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 5 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.331279277801514]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 6 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.402108669281006]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 6 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.385886192321777]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 7 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 16.865890741348267]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 7 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 16.86034846305847]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 8 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.0880389213562]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 8 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.094018697738647]
(RayTrainWorker pid=234, ip=10.0.15.42) [Epoch 9 | GPU0: Process rank 1 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.191094160079956]
(RayTrainWorker pid=227, ip=10.0.2.255) [Epoch 9 | GPU0: Process rank 0 | Batchsize: 128 | Steps: 235 | Total epoch time: 17.189364910125732]

(..)
╭───────────────────────────────╮
│ Training result               │
├───────────────────────────────┤
│ checkpoint_dir_name           │
│ time_this_iter_s      182.976 │
│ time_total_s          182.976 │
│ training_iteration          1 │
│ accuracy               0.8852 │
│ loss                  0.41928 │
╰───────────────────────────────╯

(...) Total running time: 3min 7s

Result(
  metrics={'loss': 0.4192830347106792, 'accuracy': 0.8852},
  (...)
)
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

## Troubleshooting

* Error: creating ECS Service (...): InvalidParameterException: The specified capacity provider (...) was not found: There are some cases where the capacity provider is still being created and is not ready to be used by a service. Execute "terraform apply" again to solve the issue.


## Support

Please open an issue for questions or unexpected behavior
