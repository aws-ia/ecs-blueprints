
# Import modules
import boto3
import os
import json
import time
from pprint import pprint
import logging
from botocore.exceptions import ClientError
from botocore.config import Config
import datetime

# Create logger 
#logging.basicConfig(filename='consumer.log', level=logging.INFO)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Define config
config = Config(
   retries = {
      'max_attempts': 10,
      'mode': 'standard'
   }
)

# Define session and resources
session = boto3.Session()
sqs = session.resource('sqs', config=config, region_name='us-west-2')
cloudwatch = session.client('cloudwatch', config=config)

queue_name = os.environ['queue_name']
app_metric_name = os.environ['app_metric_name']
metric_type = os.environ['metric_type']
metric_namespace = os.environ['metric_namespace']


def publishMetricValue(metricValue):

    now = datetime.datetime.now()
    logger.info('Time {} publishMetricValue with metric_namespace {} app_metric_name {} metricValue {} metric_type {} queue_name {}'.format(now, metric_namespace, app_metric_name, metricValue,metric_type, queue_name))
    response = cloudwatch.put_metric_data(
        Namespace = metric_namespace,
        MetricData = [
            {
                'MetricName': app_metric_name,
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

if __name__=="__main__":

    # Initialize variables 
    logger.info('Environment queue_name {} app_metric_name {} metric_type {} metric_namespace {}'.format(queue_name, app_metric_name, metric_type, metric_namespace))
    logger.info('Calling get_queue_by_name....')
    queue = sqs.get_queue_by_name(QueueName=queue_name)
    batchSize = 1
    queueWaitTime= 5

    # start continuous loop
    logger.info('Starting queue consumer process....')
    while True: 

        try:
            
            # Read messages from queue
            logger.info('Polling messages from the   processing queue')
            messages = queue.receive_messages(AttributeNames=['All'], MaxNumberOfMessages=batchSize, WaitTimeSeconds=queueWaitTime) 
            if not messages: continue
        
            
            logger.info('-- Received {} messages'.format(len(messages)))
            
            # Process messages
            for message in messages:
                now = datetime.datetime.now()
                messageBody = json.loads(message.body)
                processingDuration = messageBody.get('duration')
                logger.info('Time {} Processing message_id {} messageBody {}...'.format(now, message.message_id, messageBody))
                time.sleep(processingDuration)
                
                # Delete the message
                message.delete()
                now = datetime.datetime.now()
                
                # Report message duration to cloudwatch
                publishMetricValue(processingDuration)

        except ClientError as error: 
            logger.error('SQS Service Exception - Code: {}, Message: {}'.format(error.response['Error']['Code'],error.response['Error']['Message']))
            continue   

        except Exception as e: 
            logger.error('Unexpected error - {}'.format(e))


