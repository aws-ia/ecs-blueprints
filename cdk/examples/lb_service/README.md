# ECS frontend service with Application Load Balancer(ALB)

This solution blueprint creates a web-facing load balanced ECS service. There are two steps to deploying this service:

* Deploy the [core_infra](../core_infra/README.md). Note if you have already deployed the infra then you can reuse it as well.
* Modify the variables inside `cdk.json` so that CDK can import your VPC, ECS Cluster, your task execution role and other variables like backend service. You can find those variables by looking at the core infrastructure modules outputs in AWS CloudFormation. Also, if you want to use example `application-code`, then fork [this repository](https://github.com/aws-ia/ecs-blueprints).
* Deploy the CDK templates in this repository using `cdk deploy`.

```bash
# frontend-service is CDK stack name
cdk deploy frontend-service
```

<p align="center">
  <img src="../../docs/lb-service.png"/>
</p>

The solution has following key components:

* **AWS Application Load Balancer**: We are using Application Load Balancer for this service. Note the following key attributes for ALB:
  * ALB security group - allows ingress from any IP address to port 80 and allows all egress
  * ALB subnet - ALB is created in a public subnet
  * Listener - listens on port 80 for protocol HTTP
  * Target group - Since we are using Fargate launch type, the targe type is IP since each task in Fargate gets its own ENI and IP address. The target group has container port (3000) and protocol (HTTP) where the application container will serve requests. The ALB runs health check against all registered targets. In this example, ALB send HTTP GET request to path "/" to container port 3000. We are using target group default health check settings. You can tune these settings to adjust the time interval and frequency of health checks. It impacts how fast tasks become available to serve traffic. (See [ALB target health check documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html) to learn more.)
* **Amazon ECR repository** for the container image. We are using only one container image for the task in this example.
* **Amazon ECS** service definition:
  * Task security group: allows ingress for TCP from the ALB security group to the container service port (3000 for this example). And allows all egress.
  * Service discovery: You can register the service to AWS Cloud Map registry. You just need to provide the `namespace` but make sure the namespace is created in the `core_infra` step.
  * Tasks for this service will be deployed in private subnet
  * Service definition takes the load balancer target group created above as input.
  * Task definition consisting of task vCPU size, task memory, and container information including the above created ECR repository URL.
  * Task definition also takes the task execution role ARN which is used by ECS agent to fetch ECR images and send logs to AWS CloudWatch on behalf of the task.

The second half of `app.py` focuses on creating CI/CD pipeline using AWS CodePipeline and CodeBuild. This has following main components:

* **Please make sure you have stored the Github access token in AWS Secrets Manager as a plain text secret (not as key-value pair secret). This token is used to access the *application-code* repository and build images.**

* S3 bucket to store CodePipeline assets. The bucket is encrypted with AWS managed key.
* CodeBuild for building container images
  * Needs the S3 bucket created above
  * IAM role for the build service
  * The *buildspec_path* is a key variable to note. It points to the [buildspec.yml](https://github.com/aws-ia/ecs-blueprints/blob/main/application-code/ecsdemo-frontend/templates/buildspec.yml) file which has all the instructions not only for building the container but also for pre-build processing and post-build artifacts preparation required for deployment.
  * A set of environment variables including repository URL and folder path.
* CodePipeline to listen for changes to the repository and trigger build and deployment.
  * Needs the S3 bucket created above
  * Github token from AWS Secrets Manager to access the repository with *application-code* folder
  * Repository owner
  * Repository name
  * Repository branch
  * The cluster and service names for deploying the tasks with new container images
  * The image definition file name which contains mapping of container name and container image. These are the containers used in the task.
  * IAM role

Note that the CodeBuild and CodePipeline services are provisioned and configured here. However, they primarily interact with the *application-code/ecsdemo-frontend* repository. CodePipeline is listening for changes and checkins to that repository. And CodeBuild is using the *Dockerfile* and *templates/* files from that application folder.

## Cleanup

Prior to deleting the a stack with provisioned ECR repository, run the following command to delete existing images

```bash
aws ecr batch-delete-image \
    --repository-name ecsdemo-frontend \
    --image-ids "$(aws ecr list-images --repository-name ecsdemo-frontend --query 'imageIds[*]' --output json
)" || true
```
