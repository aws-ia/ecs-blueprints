# ECS Fargate parallel data processing using StepFunctions
One of the most commonly used patterns for Step Functions is the invocation of Lambda functions to perform tasks. While this works well for use cases with short lived tasks, the short time constraints of lambda do not work well with use cases that require longer running tasks.  For example, consider the use case of regulators that process data submitted by hundreds of thousands of clients. This data is usually processed in batches and in some cases, on an ad-hoc basis.  Data processing tasks, whether it is preparing data or transforming large data sets, are time consuming. Lambda functions can run for up to 15 minutes, at which point they will timeout, regardless of the state they are in, meaning that loss of data or worse things may happen (data corruption for example). In addition to the potential failure because of the timeout, we have to also consider the costs. Lambda functions are billed by 1ms segments, and while they are cheap, the longer they run, the more expensive they become. Additionally, functions that do compute heavy work may require more memory allocated to them, and adding memory to a Lambda increases the runtime cost.

This is where ECS (Elastic Container Service) shines. ECS allows you to run containers quickly and easily on AWS servers, so all you need is a working container image with your app/task code bundled in and you can quickly deploy full applications/tasks without a lot of the deployment overhead.  In the data processing use case above, ECS allows you to run longer running tasks that prepare and process large data sets as tasks. Additionally, you can configure memory and CPU requirements for the different types of tasks you have in your workflow. This results in lower costs as well as a more efficient workflow.  Different integrations with various AWS services provide the flexibility to adapt to any kind of workload that you may have.

This solution blueprint deploys an end to end data processing pipeline using Lambda, ECS Fargate and S3. This blueprint enables you to process a large number of files in S3 in parallel and pass the files on to be consumed by another job or service. For example, validating the incoming files from clients and cleaning up the data for further processing.

The solution is implemented as a StepFunction workflow that integrates with ECS to perform the validation steps and notifies different systems at the end of the workflow to indicate completion. The validation step is broken down into multiple parallel tasks, working on different chunks of the dataset. Once the workflow is complete, it sends an event so downstream systems that are interested in the completion event can take action on the processed data.

The above solution can be used not only for batch processing, but is flexible enough to be used with On Demand processing as well.

This blueprint expects csv data files uploaded to an S3 source bucket, in a "__prefix__/incoming/" folder. At a given schedule configured in EventBridge, the workflow is triggered to process the uploaded files.

## **Deployment**
### Prerequisites

---

- [AWS CDK](https://aws.amazon.com/getting-started/guides/setup-cdk/module-two/)
- [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Configure the AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) on your machine
- [Git](https://github.com/git-guides/install-git) if you prefer to clone the source from github. If not, you may download the code from github as a zip file and unzip on your local device.
- AWS account with administrator role access
- [Docker](https://docs.docker.com/engine/install/) to build the task container
- [Python](https://www.python.org/downloads/) 3.10+ if you use python for CDK deployments

----

### **Build the container**
The blueprint requires the ecs container (process-data) to exist in your ECR repository.
An example task is provided under `application-code/data-pipeline-task` in the root of the `ecs-blueprints` source. Use the below command to build and deploy the container image.

**Note** Please ensure Docker daemon is running prior to building the image and [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) is configured for an account and region and your role has permissions to deploy to ECR.
```
cd  ecs-blueprints/application-code/data-pipeline-task
./build.sh -i process-data -r <region>
```
Once created and pushed to the ECR repository, you will only run the above steps if there are changes to the task.

### **Deploy the blueprint**
---
### Typescript cdk deployment

Navigate to the `typescript` folder and run the below commands to deploy the blueprint.

**Note** This creates an ECS cluster and vpc to run the tasks. Does not create other resources required to run long running services.

```shell
cdk bootstrap
cdk deploy
```
---
### Python cdk deployment
Navigate to the `python` folder. Copy the provided `sample.env` file to `.env` and populate the `.env` file with the account and region for the deployment

Deploy the core infra stack.

**Note** This creates resources required to run tasks and services in an ECS cluster
```shell
cdk bootstrap
cdk deploy CoreInfraStack
```

Deploy the blueprint
```shell
cdk deploy DataPipelineBlueprintStack
```
---

### **Test the blueprint**
Use the below commands to copy a publicly available NOAA dataset into the bucket for testing the blueprint (replace `<DataPipelineBlueprintStack.DataPipelineBucketName>` with the output from CDK deployment). The files are copied to the bucket in the folder structure (__prefix__/incoming/) expected by the data preparation lambda.

```shell
 aws s3 sync s3://noaa-ghcn-pds/csv/by_year/ s3://<DataPipelineBlueprintStack.DataPipelineBucketName>/noaa1/incoming/ --exclude "*" --include "17[0-5]*.csv"
 aws s3 sync s3://noaa-ghcn-pds/csv/by_year/ s3://<DataPipelineBlueprintStack.DataPipelineBucketName>/noaa2/incoming/ --exclude "*" --include "17[6-9]*.csv"
 aws s3 sync s3://noaa-ghcn-pds/csv/by_year/ s3://<DataPipelineBlueprintStack.DataPipelineBucketName>/noaa3/incoming/ --exclude "*" --include "18[0-5]*.csv"
 aws s3 sync s3://noaa-ghcn-pds/csv/by_year/ s3://<DataPipelineBlueprintStack.DataPipelineBucketName>/noaa4/incoming/ --exclude "*" --include "18[6-9]*.csv"
```

Trigger the StepFunction workflow in the AWS Management console or wait for the Eventbridge rule to trigger (configured for 10 PM UTC daily via a cron rule).
Check the tasks running in the Elastic Container Service cluster. There will be 4 tasks running in parallel, processing files under each __prefix__.

## **Blueprint Architecture**

<p align="center">
  <img src="../../docs/StepFunctions_ECS_S3_Blueprint.png"/>
</p>

The solution has following key components:

* S3 source bucket to upload the csv files.
* StepFunction workflow that orchestrates the processing pipeline
* Lambda function that prepares the data for submission to ecs tasks.
* Parallel ECS Fargate tasks process the csv files from source S3 bucket and log the validation output in Cloudwatch. This can be modified to output clean files to another S3 bucket or load the data into a database.
* EventBridge event that indicates the processing result for the files in a  __prefix__
