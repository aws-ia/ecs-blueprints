# Running Backstage app on ECS Fargate
[Backstage.io](https://backstage.io) is an open platform for building developer portals. This solution blueprint deploys a backstage application on ECS Fargate with Aurora PostgreSQL serverless backend and ALB.

# Prerequisites
* Install the [prerequisites](https://backstage.io/docs/getting-started/#prerequisites) for backstage application.
* [Create the backstage application](https://backstage.io/docs/getting-started/#create-your-backstage-app)
```bash
npx @backstage/create-app
[give app name] unicorn-ui (for this example)
```
* Copy the following items to your backstage application
  * `app-config.yaml`
  * `templates/`
* Commit the application to your github repository
  ```bash
  git init
  git remote add origin https://github.com/<github_username>/unicorn-ui.git
  git branch -M main
  git push -u origin main
  ```

* Create two secrets and store them in AWS Secret Manager in the region where you will deploy this blueprint
  * GitHub token to access your repository for both CI/CD and for Backstage artifacts
  * A secure password to use for PostgresDB backend for backstage application

  ```bash
  aws secretsmanager create-secret --name ecs-github-token --secret-string "<github-token-created-above>"
  ```
  ```bash
  aws secretsmanager create-secret --name postgresdb_passwd --secret-string "<insert-db-password>"
  ```
Now we can deploy the blueprint

* Deploy the [core-infra](../core-infra/README.md). Note if you have already deployed the infra then you can reuse it as well.
* In this folder, copy the `terraform.tfvars.example` file to `terraform.tfvars` and update the variables.
  * Use the AWS Secrets Manager secret name containing the plaintext Github access token for variable `github_token_secret_name` and the PostgresDB password secret name for `postgresdb_master_password`
* **NOTE:** Codestar notification rules require a **one-time** creation of a service-linked role. Please verify one exists or create the codestar-notification service-linked role.
  ```shell
  aws iam get-role --role-name AWSServiceRoleForCodeStarNotifications
  An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name AWSServiceRoleForCodeStarNotifications cannot be found.
  ```
  *  If you receive the error above, please create the service-linked role below.
  ```shell
  aws iam create-service-linked-role --aws-service-name codestar-notifications.amazonaws.com
  ```
  * Again, once this is created, you will not have to complete these steps for the other examples.  
* Now you can deploy this blueprint
```shell
terraform init
terraform plan
terraform apply -auto-approve
```

The solution has following key components:
* Aurora: Running PostgreSQL engine in serverless mode
* AWS Secrets Manager to store the GitHub token and Postgres database password and make them available to the backstage application container at runtime
* AWS SSM Parameter store for storing and providing `POSTGRES_HOST`, `POSTGRES_USER`, and `POSTGRES_PORT` settings to the backstage applicaiton at runtime.
* ALB: We are using Application Load Balancer for this service. Note the following key attributes for ALB:
    * ALB security group - allows ingress from any IP address to port 80 and allows all egress
    * ALB subnet - ALB is created in a public subnet
    * Listener - listens on port 80 for protocol HTTP
    * Target group - Since we are using Fargate launch type, the targe type is IP since each task in Fargate gets its own ENI and IP address. The target group has container port (7007) and protocol (HTTP) where the application container will serve requests. The ALB runs health check against all registered targets. We are using target group default health check settings. You can tune these settings to adjust the time interval and frequency of health checks. It impacts how fast tasks become available to serve traffic. (See [ALB target health check documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html) to learn more.)
* ECR registery for the container image. We are using only one container image for the task in this example.
* ECS service definition:
    * Task security group: allows ingress for TCP from the ALB security group to the container service port (3000 for this example). And allows all egress.
    * Service discovery: You can register the service to AWS Cloud Map registry. You just need to provide the `namespace` but make sure the namespace is created in the `core-infra` step.
    * Tasks for this service will be deployed in private subnet
    * Service definition takes the load balancer target group created above as input.
    * Task definition consisting of task vCPU size, task memory, and container information including the above created ECR repository URL.
    * Task definition also takes the task execution role ARN which is used by ECS agent to fetch ECR images, send logs to AWS CloudWatch on behalf of the task, fetch parameters from SSM Parameter Store, and fetch secrets from AWS Secrets Manager.


The second half of `main.tf` focuses on creating the CI/CD pipeline using AWS CodePipeline and CodeBuild. This has following main components:

* **Please make sure you have stored the Github access token in AWS Secrets Manager as a plain text secret (not as key-value pair secret). This token is used to access the *application-code* repository and build images.**
* S3 bucket to store CodePipeline assets. The bucket is encrypted with AWS managed key.
* SNS topic for notifications from the pipeline
* CodeBuild for building container images
    * Needs the S3 bucket created above
    * IAM role for the build service
    * The *buildspec_path* is a key variable to note. It points to the [buildspec.yml](../../application-code/ecsdemo-frontend/templates/buildspec.yml) file which has all the instructions not only for building the container but also for pre-build processing and post-build artifacts preparation required for deployment.
    * A set of environment variables including repository URL and folder path.
* CodePipeline to listen for changes to the repository and trigger build and deployment.
    * Needs the S3 bucket created above
    * Github token from AWS Secrets Manager to access the repository with *application-code* folder
    * Repository owner
    * Repository name
    * Repository branch
    * SNS topic for notifications created above
    * The cluster and service names for deploying the tasks with new container images
    * The image definition file name which contains mapping of container name and container image. These are the containers used in the task.
    * IAM role

Note that the CodeBuild and CodePipeline services are provisioned and configured here. However, they primarily interact with your *backstage-app* GitHub repository. CodePipeline is listening for changes and checkins to that repository. And CodeBuild is using the *Dockerfile* and *templates/* files from that application folder to build images.
