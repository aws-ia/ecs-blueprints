import boto3, os

sqs = boto3.client('sqs')
ecs = boto3.client('ecs')
ssm = boto3.client('ssm')
max_tasks_per_run = 100

def lambda_handler(event, context):
    max_tasks = None
    sqs_url = None
    job_mode = None
    pipeline_enabled = None
    TASK_CLUSTER = None
    TASK_CONTAINER = None
    TASK_DEFINITON = None
    TASK_SUBNET = None
    TASK_SECURITYGROUP = None
    response = ssm.get_parameters(
        Names=[
            'PIPELINE_UNPROCESSED_SQS_URL',
            'PIPELINE_ENABLED',
            'PIPELINE_ECS_MAX_TASKS',
            'PIPELINE_ECS_CLUSTER',
            'PIPELINE_ECS_TASK_CONTAINER',
            'PIPELINE_ECS_TASK_DEFINITON',
            'PIPELINE_ECS_TASK_SECURITYGROUP',
            'PIPELINE_ECS_TASK_SUBNET',
            'PIPELINE_S3_DEST_PREFIX'
        ],
        WithDecryption=True
    )
    params = response['Parameters']
    print("SSM Params: " + str(params))
    for param in params:
        if param['Name'] == 'PIPELINE_UNPROCESSED_SQS_URL':
            sqs_url = param['Value']
        if param['Name'] == 'PIPELINE_ECS_MAX_TASKS':
            max_tasks = param['Value']
        if param['Name'] == 'PIPELINE_ENABLED':
            pipeline_enabled = param['Value']
        if param['Name'] == 'PIPELINE_ECS_CLUSTER':
            TASK_CLUSTER = param['Value']
        if param['Name'] == 'PIPELINE_ECS_TASK_CONTAINER':
            TASK_CONTAINER = param['Value']
        if param['Name'] == 'PIPELINE_ECS_TASK_DEFINITON':
            taskdef = param['Value']
            TASK_DEFINITON = taskdef[:taskdef.rindex(':')]
        if param['Name'] == 'PIPELINE_ECS_TASK_SUBNET':
            TASK_SUBNET = param['Value']
        if param['Name'] == 'PIPELINE_ECS_TASK_SECURITYGROUP':
            TASK_SECURITYGROUP = param['Value']
        if param['Name'] == 'PIPELINE_S3_DEST_PREFIX':
            S3_DEST_PREFIX = param['Value']
    if (sqs_url and pipeline_enabled and max_tasks and
        TASK_CLUSTER and TASK_CONTAINER and TASK_DEFINITON and TASK_SUBNET and TASK_SECURITYGROUP):
        max_tasks = int(max_tasks)
    else:
        raise Exception("Required SSM: PIPELINE_ECS_MAX_TASKS,PIPELINE_UNPROCESSED_SQS_URL,PIPELINE_ENABLED,PIPELINE_ECS_CLUSTER,"
            "PIPELINE_ECS_TASK_CONTAINER,PIPELINE_ECS_TASK_DEFINITON,PIPELINE_ECS_TASK_SUBNET,PIPELINE_ECS_TASK_SECURITYGROUP,PIPELINE_S3_DEST_PREFIX")
    if (pipeline_enabled != "1"):
        print("ECS Pipeline is Disabled. Not starting tasks via Lambda.")
        return
    sqs_response = sqs.get_queue_attributes(
        QueueUrl=sqs_url,
        AttributeNames=[ 'ApproximateNumberOfMessages' ]
    )
    sqs_queue_size = int(sqs_response['Attributes']['ApproximateNumberOfMessages'])
    print("Current SQS Queue size: " + str(sqs_queue_size))
    if sqs_queue_size == 0:
        return
    ecs_response = ecs.list_tasks(
        cluster=TASK_CLUSTER,maxResults=100,desiredStatus='RUNNING',family=TASK_CONTAINER)
    current_running_tasks = len(ecs_response["taskArns"])
    available_tasks = max_tasks - current_running_tasks
    tasks_to_start = min([sqs_queue_size, available_tasks, max_tasks_per_run, max_tasks])
    print("ECS Tasks to start: " + str(tasks_to_start))
    if tasks_to_start<=0:
        return
    run_task_response = ecs.run_task(
        capacityProviderStrategy=[
            {
            'capacityProvider': 'FARGATE',
            'weight': 1,
            'base': 2
            }, {
            'capacityProvider': 'FARGATE_SPOT',
            'weight': 4,
            'base': 0
            }
        ],
        cluster=TASK_CLUSTER,
        taskDefinition=TASK_DEFINITON,
        overrides={
            'containerOverrides': [
            {
                'name': TASK_CONTAINER,
                'environment': [
                {
                    'name': 'PIPELINE_ECS_JOB_MODE',
                    'value': '1'
                }, {
                    'name': 'PIPELINE_S3_DEST_PREFIX',
                    'value': S3_DEST_PREFIX
                }
                ]
            }
            ]
        },
        count=tasks_to_start,
        # launchType='FARGATE',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': [TASK_SUBNET],
                'securityGroups': [TASK_SECURITYGROUP],
                'assignPublicIp': 'DISABLED'
            }
        }
    )
    return tasks_to_start
