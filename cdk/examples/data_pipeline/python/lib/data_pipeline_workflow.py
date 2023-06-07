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

      # broadcast_error_status = tasks.EventBridgePutEvents(stack, 'Broadcast error status',
      #   entries= [
      #         tasks.EventBridgePutEventsEntry(detail= sfn.TaskInput.from_json_path_at('$'), detail_type= 'Data Processing Error', source= 'data.pipeline.workflow')]
      # )

      # broadcast_error_status.next(broadcast_status)

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
      #### Add catch statements to perform different actions based on exception. Some exceptions are from the state  ####
      #### machine execution and some could be from the task being run. Here we send all errors to EventBridge.      ####
      process_data_in_parallel = sfn.Map(stack, 'Parallel Execution',
        items_path= '$.folders',
        max_concurrency= 0,
        result_path= "$.results"
      )
      # Send a custom exception from task and catch it here to perform retries or notify end customers of data errors
      process_data_in_parallel.add_catch(broadcast_status,
        errors= ["DataProcessingException","CustomException"],
        result_path= "$"
      )
      # Send a language exception from task and catch it here to notify developers if required.
      process_data_in_parallel.add_catch(broadcast_status,
        errors= ["LanguageException"],
        result_path= "$"
      )
      # Sometimes tasks can take longer than expected (they timeout!) and need to be investigated to determine success or failure.
      # Send notifications to developers to investigate result and retry separately if required.
      process_data_in_parallel.add_catch(broadcast_status,
        errors= ["States.Timeout"],
        result_path= "$"
      )
      # Fallback exception for any stepfunction error code.
      process_data_in_parallel.add_catch(broadcast_status,
        errors= ["States.ALL"],
        result_path= "$"
      )
      # Add iterator (task state to run in map) and the next state once all task executions return.
      process_data_in_parallel.iterator(process_data_task).next(broadcast_status);

      ########### Fail state when lambda unable to prepare data ############
      fail_state = sfn.Fail(stack, "No",
        cause= 'Data preparation failed',
        error= 'Lambda function returned non 200 response'
      )

      ########### Pass state when there is no data to process ###########
      pass_state = sfn.Pass(stack, "No Data",
        comment= "No data to process"
      )

      ############ Check for readiness to process data ##############
      process_readiness_check = sfn.Choice(stack, 'Ready to Process?',
        output_path= "$.body"
      ).when(sfn.Condition.number_equals('$.statusCode', 200),process_data_in_parallel
      ).when(sfn.Condition.number_equals('$.statusCode', 404), pass_state
      ).when(sfn.Condition.not_(sfn.Condition.or_(sfn.Condition.number_equals('$.statusCode',200), sfn.Condition.number_equals('$.statusCode',404))), fail_state
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
