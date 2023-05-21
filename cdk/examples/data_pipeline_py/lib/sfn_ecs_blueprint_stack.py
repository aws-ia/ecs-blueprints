import aws_cdk as cdk
import aws_cdk.aws_logs as logs
import aws_cdk.aws_s3 as s3
import aws_cdk.aws_ec2 as ec2
import aws_cdk.aws_ecs as ecs
import aws_cdk.aws_iam as iam
import aws_cdk.aws_ecr as ecr
import aws_cdk.aws_events as events
import aws_cdk.aws_events_targets as targets
import aws_cdk.aws_lambda as functions
from lib.sfn_ecs_blueprint_roles import add_step_function_role_policies, add_ecs_task_execution_role_policies, add_ecs_task_role_policies, add_lambda_execution_role_policies
from lib.sfn_ecs_blueprint_workflow import create_data_pipeline_statemachine

class SfnEcsBlueprintStack(cdk.Stack):

    def __init__(
            self, 
            scope: cdk.Stack, 
            construct_id: str,
            env: cdk.Environment, 
            **kwargs
        ):
        super().__init__(scope, construct_id, **kwargs)

        self.env = env

        log_group = logs.LogGroup(
            self,
            'DataPipelineLogGroup',
            retention=logs.RetentionDays.ONE_WEEK,
            log_group_name=cdk.PhysicalName.GENERATE_IF_NEEDED,
        )

        bucket = s3.Bucket(self, 
                        'data-pipeline-incoming-bucket',
                        encryption=s3.BucketEncryption.S3_MANAGED,
                        enforce_ssl=True,
                        versioned=True,
                        removal_policy=cdk.RemovalPolicy.RETAIN)
        
        ecs_task_execution_role = iam.Role(
            self,
            'DataPipelineEcsTaskExecutionRole',
            assumed_by=iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
            description='Role to run the data pipeline task'
        )
        ecs_task_role = iam.Role(
            self,
            'DataPipelineEcsTaskRole',
            assumed_by=iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
            description='Role assumed by task to perform its function'
        )
        sfn_execution_role = iam.Role(
            self,
            'DataPipelineSfnExecutionRole',
            assumed_by= iam.ServicePrincipal('states.amazonaws.com'),
            description='StepFunction execution role'
        )
        sfn_execution_role.add_to_principal_policy(
            iam.PolicyStatement(actions=['iam:PassRole'], 
                            effect=iam.Effect.ALLOW,
                            resources=[
                                ecs_task_execution_role.role_arn, 
                                ecs_task_role.role_arn
                            ],
                            conditions={
                                'StringLike': {'iam:PassedToService': 'ecs-tasks.amazonaws.com'}
                            }))
        lambda_execution_role = iam.Role(self, 'DataPipelineLambdaExecutionRole',
                                       assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
                                       description='Lambda execution role',
                                       managed_policies=[
                                           iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaVPCAccessExecutionRole'),
                                           iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')])
        sfn_execution_role = add_step_function_role_policies(sfn_execution_role)
        ecs_task_execution_role = add_ecs_task_execution_role_policies(ecs_task_execution_role)
        ecs_task_role = add_ecs_task_role_policies(ecs_task_role)
        lambda_execution_role = add_lambda_execution_role_policies(lambda_execution_role)

        # Create the ECS cluster
        vpc = ec2.Vpc(self, 'DataPipelineVpc', 
                      max_azs=2,
                      nat_gateways=2)
        ecs_cluster = ecs.Cluster(
          self,
          'DataPipelineCluster',
          cluster_name= 'DataPipelineCluster',
          enable_fargate_capacity_providers=True,
          vpc=vpc,
          container_insights=True)
        
        # Specify the container to use
        ecr_repository = ecr.Repository.from_repository_attributes(
          self, 
          'ecrRepository', 
          repository_name= 'process-data',
          repository_arn= 'arn:aws:ecr:'+env.region+':'+env.account+':repository/process-data'
        )

        # Create the fargate task definition
        fargate_task_definition = ecs.FargateTaskDefinition(
          self, 
          'DataPipelineTaskDefinition',
          memory_limit_mib= 512,
          cpu= 256,
          execution_role= ecs_task_execution_role,
          task_role= ecs_task_role
        )
        # Specify container to use
        container = fargate_task_definition.add_container(
          'data-processor',
          image= ecs.ContainerImage.from_ecr_repository(ecr_repository, 'latest'),
          essential= True,
          logging= ecs.AwsLogDriver(
            stream_prefix= 'ecs',
            mode= ecs.AwsLogDriverMode.NON_BLOCKING, 
            log_group=log_group)
        )

        # Create the data preparation lambda function
        data_preparation_function = functions.Function(
          self, 
          'PrepareData',
          runtime= functions.Runtime.PYTHON_3_10,
          code= functions.Code.from_asset('lambda'),
          handler= 'prepareData.lambda_handler',
          environment= {'input_bucket': bucket.bucket_name},
          role= lambda_execution_role
        )

        # Create the state machine
        data_pipeline_workflow = create_data_pipeline_statemachine(
           self,
           ecs_cluster,
           fargate_task_definition,
           container,
           data_preparation_function,
           bucket.bucket_name
        )

        # Create the EventBridge Scheduler to invoke the workflow at a given cron schedule
        eventbridge_execution_role = iam.Role(
           self, 
           'DataPipelineEventBridgeSchedulerExecutionRole',
           assumed_by= iam.ServicePrincipal('scheduler.amazonaws.com'),
           description= 'Role assumed by EventBridge scheduler to invoke workflow'
        )
        eventbridge_execution_role.add_to_principal_policy(
           iam.PolicyStatement(
            actions=['states:StartExecution'],
            effect= iam.Effect.ALLOW,
            resources=[data_pipeline_workflow.state_machine_arn]
           )
        )

        rule = events.Rule(
            self, 
            'Rule',
            schedule= events.Schedule.cron(
                minute= '0',
                hour= '22' # 10 PM everyday
            )
        )
        rule.add_target(
            targets.SfnStateMachine(
                data_pipeline_workflow, 
                role= eventbridge_execution_role
            )
        )
        