# ECS machine learning distributed training

This solution blueprint creates the infrastructure to run distributed training jobs using a [Ray cluster](https://docs.ray.io/en/latest/cluster/getting-started.html) and [PyTorch](https://pytorch.org/). The Ray head node runs on a m5.xlarge instance, while the 2 workers run on g5.12xlarge instances.

![Solution architecture](docs/architecture.png)

## Cost warning!

By default, this blueprint uses g5.12xlarge (with 4 GPUs) to showcase multi-GPU and multi-node distributed training, but **can increase costs considerably over time**. You can modify this blueprint to use g5.xlarge (with one GPU) instead from the local variable **instance_type_workers** - if you change the instance type, you need to also modify the worker task definition to use 1 GPU instead of 4 (see **resource_requirements** and container command parameter **--num-gpus**) and the example training script outline below (see **num_workers** parameter)

## Components

* Service discovery using AWS Cloud Map: The head node is registered to a private DNS using loca zones via cloud map. This allow workers to discover the head service and join the cluster
* 2 autoscaling groups: One for the head instance and other for the worker instances
* ECS service definition:
    * Task security group, task role and task execution role and
    * Service discovery ARN is used in the service definition. ECS will automatically manage the registration and deregistration of tasks to this service discovery registry.
    * Tasks for this service will be deployed in single private subnet to avoid AZ data transfer costs
    * Task definitions with GPU resource requirements
* S3 bucket to store the results

## Deployment

```shell
terraform init
terraform plan
terraform apply
```

Due to the size of the container images, it might take several minutes until the containers reach a running state

## Example: training the resnet18 model with the FashionMNIST dataset

Once the cluster is deployed, you can connect to the EC2 instance running the head container using SSM, and open a bash shell in the container from there. This is only for demonstration purposes - Using notebooks with [SageMaker](https://aws.amazon.com/sagemaker/) or [Cloud 9](https://aws.amazon.com/cloud9/) provide a better user experience to run training jobs in python than using the bash shell

1. Connect to the instance
```bash
HEAD_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=ecs-demo-distributed-ml-training-head' \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)

aws ssm start-session --target $HEAD_INSTANCE_ID
```

2. Connect to the container
```
CONTAINER_ID=$(sudo docker ps -qf "name=.*-rayhead-.*")
sudo docker exec -it $CONTAINER_ID bash
```

3. Inside the container shell, check the cluster status
```bash
ray status
```

4. Run the [training script example](./training_example.py) - you can look at the comments inside the python script to learn more about each step.
A bucket was created as part of the terraform plan, make sure to add the name of that bucket (starts with "dt-results-") as argument of the training_example.py script

```bash
export RAY_DEDUP_LOGS=0 # Makes the logs verbose per each process in the training
wget https://raw.githubusercontent.com/aws-ia/ecs-blueprints/main/terraform/ec2-examples/distributed-ml-training/training_example.py
python training_example.py YOUR_BUCKET_NAME
```

## Clean up

```shell
terraform destroy
```


## Support

Please open an issue for questions or unexpected behaviour
