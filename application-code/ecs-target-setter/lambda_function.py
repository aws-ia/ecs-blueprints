
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
cloudwatch=session.client('cloudwatch', config=config)
appautoscaling=boto3.client('application-autoscaling', config=config)

# Read environment variables
ecs_sqs_app_scaling_policy_name=os.environ['scaling_policy_name']
desired_latency=int(os.environ['desired_latency'])
default_msg_proc_duration=int(os.environ['default_msg_proc_duration'])

queue_name=os.environ['queue_name']
app_metric_name = os.environ['app_metric_name']
bpi_metric_name=os.environ['bpi_metric_name']
metric_type=os.environ['metric_type']
metric_namespace=os.environ['metric_namespace']


def publishMetricValue(metricValue):

    response = cloudwatch.put_metric_data(
        Namespace = metric_namespace,
        MetricData = [
            {
                'MetricName': bpi_metric_name,
                'Value': metricValue,
                'Dimensions': [
                    {
                        'Name': 'Type',
                        'Value': metric_type
                    },
                    {
                        'Name': 'QueueName',
                        'Value': queue_name
                    }                    
                ],
                'StorageResolution': 1
            }
        ]
    )

def getMetricValue(metric_namespace, metricName):

    # Define query
    query={
        'Id': 'query_123',
        'MetricStat': {
            'Metric': {
                'Namespace': metric_namespace,
                'MetricName': app_metric_name,
                    'Dimensions': [
                        {
                            'Name': 'Type',
                            'Value': metric_type
                        },
                        {
                            'Name': 'QueueName',
                            'Value': queue_name
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
        msgProcessingDuration=default_msg_proc_duration
    else: 
        values = response.get('MetricDataResults')[0].get('Values')
        total = sum(values)
        count = len(values)
        msgProcessingDuration =  total / count
        print("count={} total={} msgProcessingDuration={}".format(count, total, msgProcessingDuration))        
    # Return 
    return msgProcessingDuration
    


def lambda_handler(event, context):

    # Get cloudwatch metric for msg processing duration
    msgProcessingDuration=getMetricValue(metric_namespace, app_metric_name)
    print('Most recent message processing duration is {}'.format(msgProcessingDuration))

    # Calculate new target BPI (assuming latency of 5mins)
    newTargetBPI =int(desired_latency / msgProcessingDuration)
    print('New Target BPI is {}'.format(newTargetBPI))

    # Get scaling policy of ASG
    
    response =appautoscaling.describe_scaling_policies(PolicyNames=[ecs_sqs_app_scaling_policy_name], ServiceNamespace='ecs')
    policies =response.get('ScalingPolicies')  
    #pprint(policies)
    policy=policies[0]
    print(policy)

    # Get target tracking config and update target value
    TargetTrackingConfig=policy.get('TargetTrackingScalingPolicyConfiguration')
    #print(TargetTrackingConfig)
    TargetTrackingConfig['TargetValue'] = newTargetBPI
    TargetTrackingConfig['CustomizedMetricSpecification']['MetricName'] = bpi_metric_name
    TargetTrackingConfig['CustomizedMetricSpecification']['Namespace'] = metric_namespace
    TargetTrackingConfig['CustomizedMetricSpecification']['Statistic'] = 'Average'
    # TargetTrackingConfig['CustomizedMetricSpecification']['Dimensions'] =  [
    #                     {
    #                         'Name': 'Type',
    #                         'Value': metric_type
    #                     },
    #                     {
    #                         'Name': 'QueueName',
    #                         'Value': queue_name
    #                     }
    # ]
    
                        
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


# if __name__=="__main__":

#     logger.info('Calling lambda_handler...')
#     lambda_handler("", "")