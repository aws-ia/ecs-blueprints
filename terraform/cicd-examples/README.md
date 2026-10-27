# ECS + AWS CodePipeline Deployment Example

This repository serves as an example for educational purposes only. It is not intended for production use. Make sure to review and customize the scripts and configurations according to your specific requirements and security best practices.

## Overview

This directory contains an examples of Terraform code to orchestrate the deployment of infrastructure components and the deployment of new containers via green / blue.

State for the terraform is stored external in a S3 bucket.

It containers two CodePipeline examples one which will deploy the infrastructure as code (IAC) and another which will deliver new containers to the deployed infrastructure. Often the application teams are not the teams responsible for the deployment in infrastructure. These two pipelines simulate that separation of duty.

By default these examples will deploy in us-west-2.

## Prerequisites

Before deploying this example, ensure you have the following:

- An AWS account with the necessary permissions.
- AWS CLI configured with the appropriate credentials.
- JQ installed (https://jqlang.github.io/jq/download/)
- Terraform >= 1.11. The external-state roots enable S3 native state locking
  (`use_lockfile`), which is not available in older releases.

## Deployment Steps

1. Clone this repository to your local machine.

    ```bash
    git clone https://github.com/aws-ia/ecs-blueprints
    cd ecs-blueprints
    ```

2. Copy Git ignore to sub dir for future push.
    ```bash
    cp .gitignore ./terraform/.gitignore
    ```

3. Deploy S3 bucket used for external state.

    ```bash
    cd terraform/cicd-examples/external-state-bucket
    terraform init
    terraform apply
    ```

4. Set local environment variable to reference deployed state bucket.

    ```
    STATE_BUCKET=$(aws ssm get-parameters --names terraform_state_bucket --region us-west-2 | jq -r '.Parameters[0].Value')
    ```

5. Deploy the CodePipeline which will deploy the required infrastructure.
    ```bash
    cd ../iac-pipeline
    terraform init
    terraform apply -var="s3_bucket=$STATE_BUCKET"
    ```

6. Commit Terraform code to IAC repository. This will deploy the VPC, ECS Cluster, Load Balancer, and ECS Service. This make take several minutes.

    ```
    #Get IAC code commit repo
    YOUR_CODE_COMMIT_IAC_REPO=$(aws codecommit get-repository --repository-name iac_sample_repo --query 'repositoryMetadata.cloneUrlHttp' --region us-west-2 | jq -r .)

    #CD to terraform folder
    cd ../../../terraform

    git init
    git remote add origin $YOUR_CODE_COMMIT_IAC_REPO
    git add .
    git commit -m "initial commit"
    git push origin main
    ```
7. Deploy the CodePipeline which will build and deploy new containers. This root requires
   the ARNs of the ECS task execution role and task role used by the target service. The
   IaC pipeline pre-provisioned those roles as `iac-pipeline-ecs-task-execution` and
   `iac-pipeline-ecs-task`.

    ```bash
    cd cicd-examples/lb-service-container-pipeline

    TASK_EXECUTION_ROLE_ARN=$(aws iam get-role --role-name iac-pipeline-ecs-task-execution --query 'Role.Arn' --output text)
    TASK_ROLE_ARN=$(aws iam get-role --role-name iac-pipeline-ecs-task --query 'Role.Arn' --output text)

    terraform init
    terraform apply \
      -var="target_task_execution_role_arn=$TASK_EXECUTION_ROLE_ARN" \
      -var="target_task_role_arn=$TASK_ROLE_ARN"
    ```

8. Once the Pipeline has fully deployed the environment we can begin to CI/CD new containers.

    ```
    # CD to sample app director
    cd ../../../application-code/ecsdemo-cicd/

    #Get Application code commit repo
    YOUR_CODE_COMMIT_APP_REPO=$(aws codecommit get-repository --repository-name ecs_service_repo --query 'repositoryMetadata.cloneUrlHttp' --region us-west-2 | jq -r .)

    git init
    git add .
    git remote add origin $YOUR_CODE_COMMIT_APP_REPO
    git commit -m "initial application deployment"
    git push origin main
    ```

## Clean up

Starting from the ECS-Blueprints/Terraform folder. Reuse the `STATE_BUCKET`,
`TASK_EXECUTION_ROLE_ARN`, and `TASK_ROLE_ARN` variables set during deployment (see
steps 4 and 7 above).

```
cd cicd-examples/lb-service-container-pipeline/
terraform destroy \
  -var="target_task_execution_role_arn=$TASK_EXECUTION_ROLE_ARN" \
  -var="target_task_role_arn=$TASK_ROLE_ARN"
```


```
cd ../iac-pipeline
terraform destroy -var="s3_bucket=$STATE_BUCKET"
```


```
cd ../lb-service-external-state
terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=lb-service-dev.tfstate" -backend-config="region=us-west-2" -reconfigure
terraform destroy -var-file=../dev.tfvars
```

```
cd ../core-infra-external-state
terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=core-infra-dev.tfstate" -backend-config="region=us-west-2" -reconfigure
terraform destroy -var-file=../dev.tfvars
```

Finally, remove the bootstrap state bucket. S3 refuses to delete a non-empty versioned
bucket, so empty all object versions first:

```
cd ../external-state-bucket
aws s3api delete-objects --bucket "$STATE_BUCKET" \
  --delete "$(aws s3api list-object-versions --bucket "$STATE_BUCKET" \
  --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}}' --output json)"
terraform destroy
```

For detailed information on AWS CodePipeline and ECS, refer to the [AWS documentation](https://docs.aws.amazon.com/).
