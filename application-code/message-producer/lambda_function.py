
import boto3
import os
import json
import logging
import uuid
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

        # Build Msg body. A UUID is used for both the message id and the
        # deduplication id: the previous 16-bit random value collided easily
        # (birthday bound ~300 messages), and FIFO deduplication silently
        # drops any message whose MessageDeduplicationId repeats within the
        # 5-minute dedup window.
        messageId = str(uuid.uuid4())
        messageBody = {"id": messageId, "duration": default_msg_proc_duration}
        print('Sending message id: {}'.format(messageId))

        # Call API. MessageGroupId is intentionally unique per message: this
        # workload has no ordering relationship between messages, and a
        # distinct group per message lets SQS deliver them in parallel to
        # multiple consumers (a single shared group would serialize the whole
        # queue and defeat the dynamic target-tracking scale-out this example
        # demonstrates).
        response = queue.send_message(
            MessageBody=json.dumps(messageBody),
            MessageGroupId=messageId,
            MessageDeduplicationId=messageId,
        )
