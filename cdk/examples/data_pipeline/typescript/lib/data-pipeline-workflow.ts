import * as cdk from 'aws-cdk-lib'
import * as sfn from 'aws-cdk-lib/aws-stepfunctions'
import * as tasks from 'aws-cdk-lib/aws-stepfunctions-tasks'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as ecs from 'aws-cdk-lib/aws-ecs'

export function createDataPipelineStateMachine(
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
        launchTarget: new tasks.EcsFargateLaunchTarget({
          platformVersion: ecs.FargatePlatformVersion.LATEST
        }),
        integrationPattern: sfn.IntegrationPattern.RUN_JOB,
        // Comment above line and uncomment below line if you would like to send output back to the workflow
        /*integrationPattern: sfn.IntegrationPattern.WAIT_FOR_TASK_TOKEN,*/
        containerOverrides: [containerOverride],
        assignPublicIp: false,
        taskTimeout: sfn.Timeout.duration(cdk.Duration.minutes(20))
      });

      /******** Start a parallel execution of tasks in ECS. The configuration for the task to be run is above **********/
      /**** Add catch statements to perform different actions based on exception. Some exceptions are from the state ****/
      /**** machine execution and some could be from the task being run. Here we send all errors to EventBridge.     ****/
      const processDataInParallel = new sfn.Map(stack, 'Parallel Execution', {
        itemsPath: '$.folders',
        maxConcurrency: 0,
        resultPath: "$.results"
      })
      /* Send a custom exception from task and catch it here to perform retries or notify end customers of data errors */
      .addCatch(broadcastErrorStatus, {
        errors: ["DataProcessingException","CustomException"],
        resultPath: "$"
      })
      /* Send a language exception from task and catch it here to notify developers if required. */
      .addCatch(broadcastErrorStatus, {
        errors: ["LanguageException"],
        resultPath: "$"
      })
      /* Sometimes tasks can take longer than expected (they timeout!) and need to be investigated to determine success or failure.
         Send notifications to developers to investigate result and retry separately if required. */
      .addCatch(broadcastErrorStatus, {
        errors:["States.Timeout"],
        resultPath: "$"
      })
      /* Fallback exception for any stepfunction error code. */
      .addCatch(broadcastErrorStatus, {
        errors: ["States.ALL"],
        resultPath: "$"
      })
      .iterator(processDataTask)
      .next(broadcastStatus);

      /******* Fail state when lambda unable to prepare data ******/
      const failState = new sfn.Fail(stack, "No", {
        cause: 'Data preparation failed',
        error: 'Lambda function returned non 200 response'
      })

      /******* Pass state when there is no data to process ******/
      const passState = new sfn.Pass(stack, "No Data", {
        comment: "No data to process"
      })

      /******* Check for readiness to process data *******/
      const processReadinessCheck = new sfn.Choice(stack, 'Ready to Process?', {
        outputPath: "$.body"
      })
      .when(sfn.Condition.numberEquals('$.statusCode', 200), processDataInParallel)
      .when(sfn.Condition.numberEquals('$.statusCode', 404), passState)
      .when(sfn.Condition.not(sfn.Condition.or(sfn.Condition.numberEquals('$.statusCode',200), sfn.Condition.numberEquals('$.statusCode',404))), failState)
      .otherwise(failState);

      /********* STATE MACHINE DEFINITION STARTS HERE ***********/
      const prepareData = new tasks.LambdaInvoke(stack, 'Prepare Data', {
        lambdaFunction: prepareDataFunction,
        comment: "Prepare the data for processing",
        payloadResponseOnly: true
      })

      const definition = prepareData
      .next(processReadinessCheck)

      return new sfn.StateMachine(stack, "DataPipelineStateMachine", {
        definition,
        timeout: cdk.Duration.minutes(30)
      });
    }
