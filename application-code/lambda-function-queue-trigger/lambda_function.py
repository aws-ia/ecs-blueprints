import boto3
from math import ceil

sqs = boto3.client('sqs')
ecs = boto3.client('ecs')
ssm = boto3.client('ssm')

batch_size = 10
max_tasks_per_run = 100
run_task_batch_size = 10


def task_definition_family(task_definition):
    family_and_revision = task_definition.rsplit('/', 1)[-1]
    return family_and_revision.rsplit(':', 1)[0]


def task_definition_without_revision(task_definition):
    family_separator = task_definition.rfind('/')
    revision_separator = task_definition.rfind(':')
    revision = task_definition[revision_separator + 1:]

    if revision_separator > family_separator and revision.isdigit():
        return task_definition[:revision_separator]
    return task_definition


def list_tasks(cluster, family, desired_status):
    task_arns = []
    next_token = None

    while True:
        request = {
            'cluster': cluster,
            'maxResults': 100,
            'desiredStatus': desired_status,
            'family': family,
        }
        if next_token:
            request['nextToken'] = next_token

        response = ecs.list_tasks(**request)
        task_arns.extend(response.get('taskArns', []))
        next_token = response.get('nextToken')
        if not next_token:
            return task_arns


def active_task_count(cluster, task_definition):
    family = task_definition_family(task_definition)
    task_arns = set()
    for desired_status in ('RUNNING', 'PENDING'):
        task_arns.update(list_tasks(cluster, family, desired_status))
    return len(task_arns)


def run_tasks(count, cluster, task_definition, container, subnet, security_group, s3_dest_prefix):
    started_tasks = 0
    while started_tasks < count:
        batch_count = min(run_task_batch_size, count - started_tasks)
        response = ecs.run_task(
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
            cluster=cluster,
            taskDefinition=task_definition,
            overrides={
                'containerOverrides': [
                    {
                        'name': container,
                        'environment': [
                            {
                                'name': 'PIPELINE_ECS_JOB_MODE',
                                'value': '1'
                            }, {
                                'name': 'PIPELINE_S3_DEST_PREFIX',
                                'value': s3_dest_prefix
                            }
                        ]
                    }
                ]
            },
            count=batch_count,
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet],
                    'securityGroups': [security_group],
                    'assignPublicIp': 'DISABLED'
                }
            },
            propagateTags='TASK_DEFINITION'
        )
        tasks = response.get('tasks', [])
        failures = response.get('failures', [])
        if failures or len(tasks) != batch_count:
            raise RuntimeError(
                "ECS started {} of {} requested tasks; failures: {}".format(
                    len(tasks), batch_count, failures
                )
            )
        started_tasks += len(tasks)

    return started_tasks


def lambda_handler(event, context):
    max_tasks = None
    sqs_url = None
    pipeline_enabled = None
    TASK_CLUSTER = None
    TASK_CONTAINER = None
    TASK_DEFINITION = None
    TASK_SUBNET = None
    TASK_SECURITYGROUP = None
    S3_DEST_PREFIX = None
    response = ssm.get_parameters(
        Names=[
            'PIPELINE_UNPROCESSED_SQS_URL',
            'PIPELINE_ENABLED',
            'PIPELINE_ECS_MAX_TASKS',
            'PIPELINE_ECS_CLUSTER',
            'PIPELINE_ECS_TASK_CONTAINER',
            'PIPELINE_ECS_TASK_DEFINITION',
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
        if param['Name'] == 'PIPELINE_ECS_TASK_DEFINITION':
            TASK_DEFINITION = task_definition_without_revision(param['Value'])
        if param['Name'] == 'PIPELINE_ECS_TASK_SUBNET':
            TASK_SUBNET = param['Value']
        if param['Name'] == 'PIPELINE_ECS_TASK_SECURITYGROUP':
            TASK_SECURITYGROUP = param['Value']
        if param['Name'] == 'PIPELINE_S3_DEST_PREFIX':
            S3_DEST_PREFIX = param['Value']
    if (sqs_url and pipeline_enabled and max_tasks and
        TASK_CLUSTER and TASK_CONTAINER and TASK_DEFINITION and TASK_SUBNET and
        TASK_SECURITYGROUP and S3_DEST_PREFIX):
        max_tasks = int(max_tasks)
    else:
        raise Exception("Required SSM: PIPELINE_ECS_MAX_TASKS,PIPELINE_UNPROCESSED_SQS_URL,PIPELINE_ENABLED,PIPELINE_ECS_CLUSTER,"
            "PIPELINE_ECS_TASK_CONTAINER,PIPELINE_ECS_TASK_DEFINITION,PIPELINE_ECS_TASK_SUBNET,PIPELINE_ECS_TASK_SECURITYGROUP,PIPELINE_S3_DEST_PREFIX")
    if (pipeline_enabled != "1"):
        print("ECS Pipeline is Disabled. Not starting tasks via Lambda.")
        return
    sqs_response = sqs.get_queue_attributes(
        QueueUrl=sqs_url,
        AttributeNames=['ApproximateNumberOfMessages']
    )
    sqs_queue_size = int(sqs_response['Attributes']['ApproximateNumberOfMessages'])
    print("Current SQS Queue size: " + str(sqs_queue_size))
    if sqs_queue_size == 0:
        return
    current_active_tasks = active_task_count(TASK_CLUSTER, TASK_DEFINITION)
    available_tasks = max_tasks - current_active_tasks
    tasks_to_start = min([ceil(sqs_queue_size / batch_size), available_tasks, max_tasks_per_run, max_tasks])
    print("ECS Tasks to start: " + str(tasks_to_start))
    if tasks_to_start <= 0:
        return
    return run_tasks(
        tasks_to_start,
        TASK_CLUSTER,
        TASK_DEFINITION,
        TASK_CONTAINER,
        TASK_SUBNET,
        TASK_SECURITYGROUP,
        S3_DEST_PREFIX
    )
