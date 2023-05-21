import * as cdk from 'aws-cdk-lib'
import * as sfn from 'aws-cdk-lib/aws-stepfunctions'
import * as tasks from 'aws-cdk-lib/aws-stepfunctions-tasks'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as ecs from 'aws-cdk-lib/aws-ecs'

export function createDataProcessorStateMachine(
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