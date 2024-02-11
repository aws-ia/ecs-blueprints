
# Import modules
import boto3
import os
from pprint import pprint
import logging
from botocore.exceptions import ClientError
from botocore.config import Config
from datetime import datetime
from datetime import timedelta
from datetime import timezone

# Create logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Define config
config=Config(
   retries = {
      'max_attempts': 10,
      'mode': 'standard'
   }
)

# Define session and resources
session=boto3.Session()
cloudwatch=session.client('cloudwatch', config=config, region_name='us-west-2')
appautoscaling=boto3.client('application-autoscaling', config=config, region_name='us-west-2')

# Read environment variables
ecs_sqs_app_scaling_policy_name=os.environ['scaling_policy_name']
desiredLatency=int(os.environ['desired_latency'])
defaultMsgProcDuration=int(os.environ['default_msg_proc_duration'])

queueName=os.environ['queue_name']
appMetricName = os.environ['app_metric_name']
bpiMetricName=os.environ['bpi_metric_name']
metricType=os.environ['metric_type']
metricNamespace=os.environ['metric_namespace']


def publishMetricValue(metricValue):

    response = cloudwatch.put_metric_data(
        Namespace = metricNamespace,
        MetricData = [
            {
                'MetricName': bpiMetricName,
                'Value': metricValue,
                'Dimensions': [
                    {
                        'Name': 'Type',
                        'Value': metricType
                    },
                    {
                        'Name': 'QueueName',
                        'Value': queueName
                    }
                ],
                'StorageResolution': 1
            }
        ]
    )

def getMetricValue(metricNamespace, metricName):

    # Define query
    query={
        'Id': 'query_123',
        'MetricStat': {
            'Metric': {
                'Namespace': metricNamespace,
                'MetricName': appMetricName,
                    'Dimensions': [
                        {
                            'Name': 'Type',
                            'Value': metricType
                        },
                        {
                            'Name': 'QueueName',
                            'Value': queueName
                        },
                    ]
            },
            'Period': 1,
            'Stat': 'Average',
        }
    }

    response = cloudwatch.get_metric_data(
        MetricDataQueries=[query],
        StartTime=datetime.now(timezone.utc) - timedelta(seconds=86400),
        EndTime=datetime.now(timezone.utc),
    )

    #print(response)

    if not response.get('MetricDataResults')[0].get('Values'):
        msgProcessingDuration=defaultMsgProcDuration
    else:
        values = response.get('MetricDataResults')[0].get('Values')
        total = sum(values)
        count = len(values)
        msgProcessingDuration =  total / count
        print("count={} total={} msgProcessingDuration={}".format(count, total, msgProcessingDuration))
        msgProcessingDuration=response.get('MetricDataResults')[0].get('Values')[0]

    # Return
    return msgProcessingDuration



def lambda_handler(event, context):

    # Get cloudwatch metric for msg processing duration
    msgProcessingDuration=getMetricValue(metricNamespace, appMetricName)
    print('Most recent message processing duration is {}'.format(msgProcessingDuration))

    # Calculate new target BPI (assuming latency of 5mins)
    newTargetBPI =int(desiredLatency / msgProcessingDuration)
    print('New Target BPI is {}'.format(newTargetBPI))

    # Get aplication auto scaling policy of ECS

    response = appautoscaling.describe_scaling_policies(PolicyNames=[ecs_sqs_app_scaling_policy_name], ServiceNamespace='ecs')
    policies =response.get('ScalingPolicies')
    policy=policies[0]


    # Get target tracking config and update target value
    TargetTrackingConfig=policy.get('TargetTrackingScalingPolicyConfiguration')
    TargetTrackingConfig['TargetValue'] = newTargetBPI
    TargetTrackingConfig['ScaleOutCooldown'] = 240
    TargetTrackingConfig['ScaleInCooldown'] = 240

    customMetric = {
            'Metrics': [
                {
                    'Id': 'm1',
                    'Label': 'Get the queue size (the number of messages waiting to be processed)',
                    'MetricStat': {
                        'Metric': {
                            'Dimensions': [
                                {
                                    'Name': 'QueueName',
                                    'Value': queueName
                                },
                            ],
                            'MetricName': 'ApproximateNumberOfMessagesVisible',
                            'Namespace': 'AWS/SQS'
                        },
                        'Stat': 'Average'
                    },
                    'ReturnData': False
                },
                {
                    'Id': 'm2',
                    'Label': 'Get the ECS running task count (the number of currently running tasks)',
                    'MetricStat': {
                        'Metric': {
                            'Dimensions': [
                                {
                                    'Name': 'ClusterName',
                                    'Value': 'core-infra'
                                },
                                {
                                    'Name': 'ServiceName',
                                    'Value': 'ecsdemo-queue-proc3'
                                },
                            ],
                            'MetricName': 'RunningTaskCount',
                            'Namespace': 'ECS/ContainerInsights'
                        },
                        'Stat': 'Average'
                    },
                    'ReturnData': False
                },
                {
                    'Id': 'm3',
                    'Label': 'Calculate the backlog per instance',
                    'Expression': 'm1 / m2',
                    'ReturnData': True
                },
            ]
    }


    TargetTrackingConfig['CustomizedMetricSpecification'] = customMetric
    # Update scaling policy of ASG
    appautoscaling.put_scaling_policy(
        ServiceNamespace='ecs',
        ResourceId=policy.get('ResourceId'),
        ScalableDimension=policy.get('ScalableDimension'),
        PolicyName=policy.get('PolicyName'),
        PolicyType=policy.get('PolicyType'),
        TargetTrackingScalingPolicyConfiguration=TargetTrackingConfig
    )
    print('Scaling policy of ECS has been successfully updated!')

    # Publish new target BPI
    publishMetricValue(newTargetBPI)
