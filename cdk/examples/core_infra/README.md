# Core Infrastructure
This folder contains the CDK code to deploy the core infratructure for an ECS Fargate workload. The AWS resources created by the default script are:
* Networking
  * VPC
    * 3 public subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of public subnets as AZs
    * 3 private subnets, 1 per AZ. If a region has less than 3 AZs it will create same number of private subnets as AZs
    * 1 NAT Gateway
    * Associated Route Tables
    * 1 Internet Gateway
* 1 ECS Cluster with AWS CloudWatch Container Insights enabled
* Task execution IAM role
* CloudWatch log groups
* CloudMap service discovery namespace `default`

But you can change those resources by changing the `context` value in `cdk.json` file.

## Getting Started
Make sure you have all the [prerequisites](../../README.md) for your laptop.
And also you have CDK and CDK python bindings installed in a virtual environment.
reference: https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html

Assuming you have `npm`, `python(version 3.6 or later)`, `pip`, and `virtualenv`(which above link provides details to download):
```bash
npm install -g aws-cdk@latest
cdk --version

# Bootstrap your AWS account
cdk bootstrap aws://ACCOUNT-NUMBER/REGION

python3 -m venv .venv
source .venv/bin/activate

pip install aws-cdk-lib
# or you can run the command below
# make sure that your folder's current location is cdk/examples/core_infra
python -m pip install -r ../../requirements.txt
```

## Usage

* Clone the forked repository from your account (not the one from the aws-ia organization) and change the directory to the appropriate one as shown below:
```bash
cd ecs-blueprints/cdk/examples/core_infra/
```
* Copy `sample.env` to `.env` and change the `account_number` and `aws_region` values in the `.env` file:
```bash
# change the vales based on your aws account
export AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
export AWS_REGION={AWS-Region-for-ECS-resources}

sed -e "s/<ACCOUNT_NUMBER>/$AWS_ACCOUNT/g" \
  -e "s/<REGION>/$AWS_REGION/g" sample.env > .env
```

* Run CDK synth command to synthesize and do a dry run
```bash
cdk synth
```
* Run CDK ls command to figure out the list of the stacks in the app
```bash
cdk ls
```
* Review the CDK synth output, take a look at the changes that CDK will execute, and then apply them:
```bash
cdk deploy CoreInfraStack --outputs-file output.json
```

## Outputs

After the execution of the CDK code, the outputs will be in the `output.json` file. The IDs and values can be used as input for the next CDK modules. You can use this infrastructure to run other example blueprints.

## Cleanup

Run the following command if you want to delete all the resources created before. If you have created other blueprints and they use these infrastructure then destroy those blueprint resources first.

In case of cleaning up `cicd_service` blueprints, AWS CloudFormation cannot delete a non-empty Amazon ECR repository. Therefore, before executing `cdk destroy` command, executing `aws ecr delete-repository` is needed.

```bash
# cicd_service repository deletion
aws ecr delete-repository --repository-name ecsdemo-cicd --force
```

```bash
cdk destroy [cdk-stack-name]
```

## Inputs

The input values ​​below can be modified in the `cdk.json` file.
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_core_stack_name"></a> [core\_stack\_name](#input\_core\_stack\_name) | The name of Core Infrastructure stack, feel free to rename it. Used for cluster and VPC names. | `string` | `"ecs-blueprint-infra"` | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `us-east-1` | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for VPC | `string` | `"10.0.0.0/16"` | yes |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | List of service discovery namespaces for ECS services. Creates a default namespace | `list(string)` | <pre>[<br>  "default" <br>]</pre> | yes |
| <a name="input_enable_nat_gw"></a> [enable\_nat\_gw](#input\_enable\_nat\_gw) | Provision a NAT Gateway in the VPC | `bool` | `true` | yes |
| <a name="input_number_of_azs"></a> [number\_of\_azs](#input\_number\_of\_azs) | The number of Availability Zone in the VPC | `number` | 3 | yes |


## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | The ID of the ECS cluster |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | The name of the ECS cluster and the name of the core stack |
| <a name="output_ecs_cluster_security_groups"></a> [ecs\_cluster\_security\_groups](#output\_ecs\_cluster\_security\_groups) | A list of security groups |
| <a name="output_ecs_task_execution_role_arn"></a> [ecs\_task\_execution\_role\_arn](#output\_ecs\_task\_execution\_role\_arn) | The ARN of the task execution role |
| <a name="output_ecs_task_execution_role_name"></a> [ecs\_task\_execution\_role\_name](#output\_ecs\_task\_execution\_role\_name) | The ARN of the task execution role |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | A list of private subnets for the client app |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | A list of public subnets |
| <a name="output_sd_namespaces"></a> [sd\_namespaces](#output\_sd\_namespaces) | Service discovery namespaces already available |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
