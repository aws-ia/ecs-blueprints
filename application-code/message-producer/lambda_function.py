
# Import modules
import boto3
import os
import random
import os
import struct
import json
from pprint import pprint
import logging
from botocore.exceptions import ClientError
from botocore.config import Config

# Create logger
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
sqs = session.resource('sqs', config=config)

# Read  environment variables
queue_name = os.environ['queue_name']
default_msg_proc_duration = int(os.environ['default_msg_proc_duration'])
number_of_messages = int(os.environ['number_of_messages'])


def lambda_handler(event, context):

    # Get the queue
    queue = sqs.get_queue_by_name(QueueName=queue_name)

    # Send N messages
    for i in range(number_of_messages):

        # Build Msg body
        randomNumber = struct.unpack('H', os.urandom(2))[0]
        messageBody = {"id": randomNumber, "duration": default_msg_proc_duration}
        print('Sending message id: {}'.format(randomNumber))

        # Call API
        response = queue.send_message(
            MessageBody=json.dumps(messageBody),
            MessageGroupId=str(messageBody['id']),
            MessageDeduplicationId=str(messageBody['id']) + ':' + str(randomNumber),
        )
