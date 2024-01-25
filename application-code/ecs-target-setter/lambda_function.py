
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
# sqs:session.resource('sqs', config=config)
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

    # Get scaling policy of ASG
    
    print("ecs_sqs_app_scaling_policy_name={}".format(ecs_sqs_app_scaling_policy_name))
    
    response = appautoscaling.describe_scaling_policies(PolicyNames=[ecs_sqs_app_scaling_policy_name], ServiceNamespace='ecs')
    policies =response.get('ScalingPolicies')  
    #pprint(policies)
    policy=policies[0]
    #print(policy)

    # Get target tracking config and update target value
    TargetTrackingConfig=policy.get('TargetTrackingScalingPolicyConfiguration')
    #print(TargetTrackingConfig)
    TargetTrackingConfig['TargetValue'] = newTargetBPI
    TargetTrackingConfig['ScaleOutCooldown'] = 240
    TargetTrackingConfig['ScaleInCooldown'] = 240
    
    TargetTrackingConfig['CustomizedMetricSpecification']['MetricName'] = bpiMetricName
    TargetTrackingConfig['CustomizedMetricSpecification']['Namespace'] = metricNamespace
    TargetTrackingConfig['CustomizedMetricSpecification']['Statistic'] = 'Average'

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
