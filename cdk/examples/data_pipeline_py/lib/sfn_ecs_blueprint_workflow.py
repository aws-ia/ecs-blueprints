import aws_cdk as cdk 
import aws_cdk.aws_stepfunctions as sfn
import aws_cdk.aws_stepfunctions_tasks as tasks
import aws_cdk.aws_lambda as functions
import aws_cdk.aws_ecs as ecs

def create_data_pipeline_statemachine(
    stack: cdk.Stack,
    cluster: ecs.Cluster,
    task_definition: ecs.FargateTaskDefinition,
    container_definition: ecs.ContainerDefinition,
    prepare_data_function: functions.IFunction,
    bucket: str):
      ########## NOTE: State machine is defined bottoms up! ###########

      ########## Final Broadcast Status task and parallel state definitions ###########
      broadcast_task = tasks.EventBridgePutEvents(stack, 'Broadcast processing status', 
        entries= [
              tasks.EventBridgePutEventsEntry(detail= sfn.TaskInput.from_json_path_at('$'), detail_type= 'Data Processing Status', source= 'data.pipeline.workflow')]        
      )

      broadcast_status = sfn.Map(stack, 'Broadcast completion status', 
        items_path= '$.results',
        max_concurrency= 0,
        result_path= '$.results'
      ).iterator(broadcast_task)

      broadcast_error_status = tasks.EventBridgePutEvents(stack, 'Broadcast error status', 
        entries= [
              tasks.EventBridgePutEventsEntry(detail= sfn.TaskInput.from_json_path_at('$'), detail_type= 'Data Processing Error', source= 'data.pipeline.workflow')]
      )

      ######### Configurations for the ECS Task to be run ##########
      container_override = tasks.ContainerOverride(
        container_definition=container_definition,
        environment= [
              tasks.TaskEnvironmentVariable(name= 'TASK_TOKEN',value= sfn.JsonPath.task_token),
              tasks.TaskEnvironmentVariable(name= 'FOLDERNAME',value= '$.foldername'),
              tasks.TaskEnvironmentVariable(name= 'FILES',value= sfn.JsonPath.json_to_string(sfn.JsonPath.object_at('$.files'))),
              tasks.TaskEnvironmentVariable(name= 'S3_BUCKET',value= bucket)]
      )      
      process_data_task = tasks.EcsRunTask(stack, 'Process Data', 
        task_definition= task_definition,
        cluster= cluster,
        launch_target= tasks.EcsFargateLaunchTarget(platform_version=ecs.FargatePlatformVersion.LATEST),
        integration_pattern= sfn.IntegrationPattern.WAIT_FOR_TASK_TOKEN,
        container_overrides= [container_override],
        assign_public_ip= False,
        task_timeout= sfn.Timeout.duration(cdk.Duration.minutes(20))
      )

      ########## Start a parallel execution of tasks in ECS. The configuration for the task to be run is above ############
      process_data_in_parallel = sfn.Map(stack, 'Parallel Execution', 
        items_path= '$.folders',
        max_concurrency= 0,
        result_path= "$.results"
      )
      process_data_in_parallel.add_catch(broadcast_error_status, 
        errors= ["DataProcessingException","States.Timeout"],
        result_path= "$"
      )
      process_data_in_parallel.iterator(process_data_task).next(broadcast_status); 

      ########### Fail state when lambda unable to prepare data ############
      fail_state = sfn.Fail(stack, "No", 
        cause= 'Data preparation failed',
        error= 'Lambda function returned non 200 response'
      )

      ############ Check for readiness to process data ##############
      process_readiness_check = sfn.Choice(stack, 'Ready to Process?', 
        output_path= "$.body"
      ).when(sfn.Condition.number_equals('$.statusCode', 200),process_data_in_parallel
      ).when(sfn.Condition.not_(sfn.Condition.number_equals('$.statusCode',200)), fail_state
      ).otherwise(fail_state)

      ############ STATE MACHINE DEFINITION STARTS HERE ##############
      prepare_data = tasks.LambdaInvoke(stack, 'Prepare Data', 
        lambda_function= prepare_data_function,
        comment= "Prepare the data for processing",
        payload_response_only= True
      )

      definition = prepare_data.next(process_readiness_check)

      return sfn.StateMachine(stack, "DataPipelineStateMachine", 
        definition= definition,
        timeout= cdk.Duration.minutes(30)
      )