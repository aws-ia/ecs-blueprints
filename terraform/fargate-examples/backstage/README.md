# Running Backstage app on ECS Fargate
[Backstage.io](https://backstage.io) is an open platform for building developer portals. This solution blueprint deploys a backstage application on ECS Fargate with an Aurora PostgreSQL Serverless v2 backend and ALB.

**This is a shared-cluster example, not a self-contained pattern.** It does not create its
own VPC or ECS cluster; instead it looks up the VPC, subnets, cluster, and service
discovery namespace created by the sibling [core-infra](../core-infra/README.md) root (by
the fixed name `core-infra`). It also requires resources that Terraform cannot create for
you: a GitHub repository containing your Backstage application and a Secrets Manager
secret holding a GitHub token. The deploy order is:

1. Create the Backstage app and push it to your GitHub repository (out of band, below).
2. Create the GitHub token secret in AWS Secrets Manager (out of band, below).
3. Deploy [core-infra](../core-infra/README.md) with `terraform apply`.
4. Fill in `terraform.tfvars` in this folder and deploy this root with `terraform apply`.

# Prerequisites

All of the following must exist before `terraform apply` in this folder can succeed.

**1. A Backstage application in a GitHub repository you control** (referenced by the
required variables `repository_owner` and `repository_name` — neither has a default):

* Install the [prerequisites](https://backstage.io/docs/getting-started/#prerequisites) for backstage application.
* [Create the backstage application](https://backstage.io/docs/getting-started/#create-your-backstage-app)
```bash
npx @backstage/create-app
[give app name] unicorn-ui (for this example)
```
* Copy the `templates/` folder from this blueprint directory (containing `buildspec.yml`
  and `imagedefinition.json`) into the root of your backstage application. CodeBuild
  expects `./templates/buildspec.yml` in your repository, and the buildspec builds the
  backend with your app's own `app-config.yaml`.
* Configure your app's `app-config.yaml` to read its settings from the environment the
  task definition provides: `BASE_URL`, `POSTGRES_HOST`, `POSTGRES_PORT`,
  `POSTGRES_USER`, and the secrets `POSTGRES_PASSWORD` and `GITHUB_TOKEN` (for example
  `baseUrl: ${BASE_URL}`, database connection from the `POSTGRES_*` values).
* Commit the application to your github repository
  ```bash
  git init
  git remote add origin https://github.com/<github_username>/unicorn-ui.git
  git branch -M main
  git push -u origin main
  ```

**2. A GitHub token secret in AWS Secrets Manager** (referenced by the required variable
`github_token_secret_name` — no default), in the region where you will deploy this
blueprint. The token is used both by CodePipeline to pull your repository and by the
running Backstage container (`GITHUB_TOKEN`). Store it as a plain text secret (not a
key-value pair secret):

  ```bash
  aws secretsmanager create-secret --name ecs-github-token --secret-string "<github-token-created-above>"
  ```
  Aurora creates and manages the PostgreSQL master password in AWS Secrets Manager; you
  do not create that one yourself.

**3. The deployed [core-infra](../core-infra/README.md) root** in the same account and
region. This blueprint discovers the `core-infra` VPC, its public and private subnets,
the `core-infra` ECS cluster, and the `default.core-infra.local` service discovery
namespace by name; the apply fails if they do not exist.

**4. A `terraform.tfvars` file in this folder.** Copy `terraform.tfvars.example` to
`terraform.tfvars` and set `repository_owner`, `repository_name`, `repository_branch`,
and `github_token_secret_name`.

**5. The CodeStar Notifications service-linked role** (one-time per account):
  ```shell
  aws iam get-role --role-name AWSServiceRoleForCodeStarNotifications
  An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name AWSServiceRoleForCodeStarNotifications cannot be found.
  ```
  *  If you receive the error above, please create the service-linked role below.
  ```shell
  aws iam create-service-linked-role --aws-service-name codestar-notifications.amazonaws.com
  ```
  * Again, once this is created, you will not have to complete these steps for the other examples.

# Deploy

With all prerequisites in place, deploy this blueprint from this folder:
```shell
terraform init
terraform plan
terraform apply -auto-approve
```

The solution has following key components:
* Aurora: Running the PostgreSQL engine with Serverless v2 capacity
* AWS Secrets Manager to store the GitHub token and the RDS-managed PostgreSQL password and make them available to the backstage application container at runtime (as the `GITHUB_TOKEN` and `POSTGRES_PASSWORD` container secrets)
* Container environment variables providing the `BASE_URL`, `POSTGRES_HOST`, `POSTGRES_USER`, and `POSTGRES_PORT` settings to the backstage application at runtime.
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
    * The *buildspec_path* is a key variable to note. It points to `./templates/buildspec.yml` in the application repository, which contains the build, pre-build, and post-build instructions required for deployment.
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

## Production considerations

This blueprint takes two shortcuts that are acceptable for a demo but should be changed
before any real use:

* **Database access runs as the `postgres` superuser.** The task connects with
  `POSTGRES_USER = "postgres"`, the Aurora master user. For production, create a
  dedicated application role in the database with only the privileges Backstage needs
  (typically `CREATEDB` or pre-created per-plugin databases plus read/write on them),
  store its credentials in AWS Secrets Manager, and point `POSTGRES_USER`/
  `POSTGRES_PASSWORD` at that secret instead of the cluster master user secret.
* **The app and backend `BASE_URL`s use `http://`.** The ALB listens on port 80 only.
  For production, request or import an ACM certificate for your domain, add an HTTPS
  (443) listener that terminates TLS with that certificate, redirect HTTP to HTTPS, and
  change the `BASE_URL` environment values to `https://your-domain`. See the HTTPS
  section below.

## HTTPS

The ALB in this example is HTTP-only to avoid a domain-name prerequisite. To serve
traffic over TLS:

1. Create or import a certificate in AWS Certificate Manager (ACM) in the deployment
   Region for the domain that will point at the ALB.
2. Add an HTTPS listener on port 443 to the `alb` module (`protocol = "HTTPS"`,
   `certificate_arn` set to the ACM certificate) forwarding to the same `ecs-task`
   target group.
3. Change the port 80 listener to a `redirect` action returning `HTTP_301` to port 443
   instead of forwarding, so all plaintext requests are upgraded.

## Cost

This example creates billable AWS resources. Review `terraform plan`, use a sandbox account, and avoid leaving the stack deployed when it is not in use. NAT gateways, load balancers, databases, and accelerated instances are common cost drivers where present.

## Quotas

Confirm that the target Region has sufficient ECS task, elastic network interface, load balancer, and any workload-specific service quotas before deployment. EC2 examples also require available capacity for the selected instance types.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review `terraform plan` before applying. After deployment, use the functional check described above and inspect ECS service events and CloudWatch Logs for task failures.

## Cleanup

Run `terraform destroy` from this example directory. Remove retained data or separately created secrets only after confirming they are no longer needed.
