import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3'
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as sfn from 'aws-cdk-lib/aws-stepfunctions';
import * as tasks from 'aws-cdk-lib/aws-stepfunctions-tasks';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import { Effect, ManagedPolicy, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { 
  addStepFunctionRolePolicies, 
  addEcsTaskExecutionRolePolicies, 
  addEcsTaskRolePolicies,
  addLambdaExecutionRolePolicies
} from './sfn-ecs-blueprint-roles';

import { Repository } from 'aws-cdk-lib/aws-ecr';
import { ISubnet, Vpc } from 'aws-cdk-lib/aws-ec2';
import { EcsApplication } from 'aws-cdk-lib/aws-codedeploy';


export class SfnEcsBlueprintStack extends cdk.Stack {
  
  private stepFunctionExecutionRole: Role;
  private ecsTaskExecutionRole: Role;
  private ecsTaskRole: Role;
  private lambdaExecutionRole: Role;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Bucket for incoming files
    const bucket = new s3.Bucket(this, 'data-processing-incoming-bucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Build the roles
    // * StepFunction execution role - Role assumed by Step Function
    // * Ecs Task Execution Role - Role assumed by ECS to execute tasks
    // * Ecs Task Role - Role assumed by task to perform its job
    // * Lambda execution role - Role to be assumed by Lambda to parse S3  
    this.ecsTaskExecutionRole = new Role (this, 'DataProcessorEcsTaskExecutionRole', {
      assumedBy: new ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: 'Role to run an ECS task'
    });
    this.ecsTaskRole = new Role (this, 'DataProcessorEcsTaskRole', {
      assumedBy: new ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: 'Role assumed by task to perform its function'
    });
    this.stepFunctionExecutionRole = new Role(this, 'DataProcessorStepFunctionExecutionRole', {
      assumedBy: new ServicePrincipal('states.amazonaws.com'),
      description: 'Stepfunction execution role'
    });
    this.stepFunctionExecutionRole.addToPrincipalPolicy(new PolicyStatement({
      actions: ["iam:PassRole"],
      effect: Effect.ALLOW,
      resources: [this.ecsTaskExecutionRole.roleArn, this.ecsTaskRole.roleArn],
      conditions: {StringLike: {
        "iam:PassedToService": "ecs-tasks.amazonaws.com"
      }}
    }))
    this.lambdaExecutionRole = new Role(this, "DataProcessorLambdaExecutionRole", {
      assumedBy: new ServicePrincipal('lambda.amazonaws.com'),
      description: 'Lambda execution role',
      managedPolicies: [
        ManagedPolicy.fromAwsManagedPolicyName("service-role/AWSLambdaVPCAccessExecutionRole"),
        ManagedPolicy.fromAwsManagedPolicyName("service-role/AWSLambdaBasicExecutionRole")
      ]
    })
    addStepFunctionRolePolicies(cdk.Stack.of(this).account, cdk.Stack.of(this).region, this.stepFunctionExecutionRole);
    addEcsTaskExecutionRolePolicies(cdk.Stack.of(this).account, cdk.Stack.of(this).region, this.ecsTaskExecutionRole);
    addEcsTaskRolePolicies(cdk.Stack.of(this).account, cdk.Stack.of(this).region, this.ecsTaskRole);
    addLambdaExecutionRolePolicies(cdk.Stack.of(this).account, cdk.Stack.of(this).region, this.lambdaExecutionRole);

    // Create the ECS Cluster
    const vpc = new Vpc(this, 'DataProcessorVpc', { maxAzs: 2 });
    const ecsCluster = new ecs.Cluster(this, "DataProcessorCluster", {
      clusterName: "DataProcessorCluster",
      enableFargateCapacityProviders: true,
      vpc
    });

    // Specify the container to use
    const ecrRepository = Repository.fromRepositoryAttributes(this, 'ecrRepository', {
      repositoryName: 'process-data',
      repositoryArn: `arn:aws:ecr:${cdk.Stack.of(this).region}:${cdk.Stack.of(this).account}:repository/process-data`
    });

    // Create the fargate task definition
    const fargateTaskDefinition = new ecs.FargateTaskDefinition(this, 'FargateTaskDefinition', {
      memoryLimitMiB: 512,
      cpu: 256,
      executionRole: this.ecsTaskExecutionRole,
      taskRole: this.ecsTaskRole
    });
    const container = fargateTaskDefinition.addContainer('data-processor', {
      image: ecs.ContainerImage.fromEcrRepository(ecrRepository, "latest"),
      memoryLimitMiB: 512,
      essential: true,
      logging: new ecs.AwsLogDriver({
        streamPrefix: "ecs",
        mode: ecs.AwsLogDriverMode.NON_BLOCKING
      })
    });

    const dataPreparationFunction = new lambda.Function(this, "PrepareData", {
      runtime: lambda.Runtime.PYTHON_3_10,
      code: lambda.Code.fromAsset('lambda'),
      handler: 'prepareData.lambda_handler',
      environment: {
        "input_bucket": bucket.bucketName
      },
      role: this.lambdaExecutionRole
    })

    createDataProcessorStateMachine(this, 
      ecsCluster, 
      fargateTaskDefinition, 
      container, 
      dataPreparationFunction,
      bucket.bucketName)
  }
}

function createDataProcessorStateMachine(
stack: cdk.Stack, 
cluster: ecs.Cluster, 
taskDefinition: ecs.FargateTaskDefinition, 
containerDefinition: ecs.ContainerDefinition, 
prepareDataFunction: lambda.IFunction,
bucket: string) 
{
  /*******NOTE: State machine is defined bottoms up! ***********/

  /********* Final Broadcast Status task and parallel state definitions **********/
  const broadcastTask = new tasks.EventBridgePutEvents(stack, 'Broadcast processing status', {
    entries: [{
      detail: sfn.TaskInput.fromJsonPathAt('$'),
      detailType: "Data Processing Status",
      source: "data.processor.workflow"
    }]
  })

  const broadcastStatus = new sfn.Map(stack, "Broadcast completion status", {
    itemsPath: "$.results",
    maxConcurrency: 0,
    resultPath: "$.results"
  }).iterator(broadcastTask);

  const broadcastErrorStatus = new tasks.EventBridgePutEvents(stack, 'Broadcast error status', {
    entries: [{
      detail: sfn.TaskInput.fromJsonPathAt('$'),
      detailType: "Data Processing Error",
      source: "data.processor.workflow"
    }]
  })

  /******* Configurations for the ECS Task to be run ************/
  const containerOverride: tasks.ContainerOverride = {
    containerDefinition,  
    environment: [{
      name: 'TASK_TOKEN',
      value: sfn.JsonPath.taskToken,
    },
    {
      name: "FOLDERNAME",
      value: "$.foldername"
    },
    {
      name: "FILES",
      value: sfn.JsonPath.jsonToString(sfn.JsonPath.objectAt("$.files"))
    },
    {
      name: "S3_BUCKET",
      value: bucket
    }]
  };

  const processDataTask = new tasks.EcsRunTask(stack, 'Process Data', {
    taskDefinition,
    cluster,
    launchTarget: new tasks.EcsFargateLaunchTarget(),
    integrationPattern: sfn.IntegrationPattern.WAIT_FOR_TASK_TOKEN,
    containerOverrides: [containerOverride],
    assignPublicIp: true,
    taskTimeout: sfn.Timeout.duration(cdk.Duration.minutes(20))
  });

  /******** Start a parallel execution of tasks in ECS. The configuration for the task to be run is above **********/
  const processDataInParallel = new sfn.Map(stack, 'Parallel Execution', {
    itemsPath: '$.folders',
    maxConcurrency: 0,
    resultPath: "$.results"
  })
  .addCatch(broadcastErrorStatus, {
    errors: ["DataProcessingException","States.Timeout"],
    resultPath: "$"
  })
  .iterator(processDataTask)
  .next(broadcastStatus); /** section above **/

  /******* Fail state when lambda unable to prepare data ******/
  const failState = new sfn.Fail(stack, "No", {
    cause: 'Data preparation failed',
    error: 'Lambda function returned non 200 response'
  })

  /******* Check for readiness to process data *******/
  const processReadinessCheck = new sfn.Choice(stack, 'Ready to Process?', {
    outputPath: "$.body"
  })
  .when(sfn.Condition.numberEquals('$.statusCode', 200), processDataInParallel) /** section above **/
  .when(sfn.Condition.not(sfn.Condition.numberEquals('$.statusCode',200)), failState)
  .otherwise(failState);

  /********* STATE MACHINE DEFINITION STARTS HERE ***********/
  const prepareData = new tasks.LambdaInvoke(stack, 'Prepare Data', {
    lambdaFunction: prepareDataFunction,
    comment: "Prepare the data for processing",
    payloadResponseOnly: true
  })

  const definition = prepareData
  .next(processReadinessCheck)

  return new sfn.StateMachine(stack, "ECSMapIntegrationStateMachine", {
    definition,
    timeout: cdk.Duration.minutes(30)
  });
}

