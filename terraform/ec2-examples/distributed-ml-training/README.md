# ECS machine learning distributed training

This solution blueprint creates the infrastructure to run distributed training jobs using a Ray cluster and Pytorch. The Ray head node runs on a m5.xlarge instance, while the 2 workers run on g5.12xlarge instances. 

## Cost warning!

By default, this blueprint uses g5.12xlarge (with 4 GPUs) to showcase multi-GPU and multi-node distributed training, but **can increase costs considerably over time**. You can modify this blueprint to use g5.xlarge (with one GPU) instead from the local variable **instance_type_workers** - if you change the instance type, you need to also modify the worker task definition to use 1 GPU instead of 4 (see **resource_requirements** and container command parameter **--num-gpus**)

## Deployment

```shell
terraform init
terraform plan
terraform apply 
```

## Components

* Service discovery using AWS Cloud Map: The head node is registerer to a private DNS using loca zones via cloud map. This allow workers to discover the head service and join the cluster
* 2 autoscaling groups: One for the head instance and other for the worker instances
* ECS service definition:
    * Task security group, task role and task execution role and 
    * Service discovery ARN is used in the service definition. ECS will automatically manage the registration and deregistration of tasks to this service discovery registry.
    * Tasks for this service will be deployed in private subnet
    * Task definitions with GPU resource requirements

## Support

Please open an issue for questions or unexpected behaviour