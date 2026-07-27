# Load-balanced service container pipeline

This root creates a CodeCommit repository, ECR repository, CodeBuild project, and
CodePipeline that builds and deploys the `ecsdemo-cicd` container through CodeDeploy.
Deploy the external-state core and load-balanced service examples first: the deploy
stage expects the CodeDeploy application
`deploy_development_ecsdemo-frontend`, deployment group
`deployment-group-deploy_development_ecsdemo-frontend`, ECS cluster
`core-infra-external-state`, and service `ecsdemo-frontend`.

Pass the existing service's task roles so CodePipeline can register the replacement task
definition without receiving `iam:PassRole` access to other roles:

```shell
terraform init
terraform plan \
  -var="target_task_execution_role_arn=<TASK_EXECUTION_ROLE_ARN>" \
  -var="target_task_role_arn=<TASK_ROLE_ARN>" \
  -out=tfplan
terraform apply tfplan
```

Push the contents of `application-code/ecsdemo-cicd` to the generated
`ecs_service_repo` CodeCommit repository. Its `buildspec-cicd.yml` creates the task
definition and AppSpec artifacts consumed by the deploy stage.

## Cost

CodeBuild compute and CodePipeline executions are the primary usage charges in this
root. ECR images, pipeline artifacts in S3, and CloudWatch Logs continue to consume
storage while idle. The prerequisite ECS service also incurs its own Fargate, load
balancer, and networking costs.

## Quotas

Check CodePipeline, CodeBuild concurrent build, ECR repository, S3 bucket, IAM role, ECS
task, and CodeDeploy quotas. CodeCommit is not available to accounts that have not
previously used it; use a supported source action before deploying this example in such
an account. The supplied buildspec targets `us-west-2`, so update it together with
`var.region` when using another Region.

## Validation

Run `terraform fmt -check`, `terraform validate`, and review `terraform plan`. After
applying, push a test commit and verify that all three stages report `Succeeded`:

```shell
aws codepipeline get-pipeline-state \
  --name example-application-pipeline \
  --query 'stageStates[].{stage:stageName,status:latestExecution.status}'
```

Confirm that the ECS service uses the newly built image and that the service's load
balancer target is healthy. Request the load balancer URL and verify the response before
accepting the deployment as functional.

## Cleanup

Stop source changes, let any running execution finish, and destroy this pipeline before
destroying the target service:

```shell
terraform destroy
```

The ECR repository must be empty before Terraform can delete it. Remove test images when
they are no longer needed, then destroy the load-balanced service and shared core roots
in that order.
