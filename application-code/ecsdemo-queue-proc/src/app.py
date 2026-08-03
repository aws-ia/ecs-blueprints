
# Import modules
import boto3
import os
import json
import signal
import sys
import time
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

# Region resolution: prefer the standard AWS environment variables (the ECS
# task definition in terraform/fargate-examples/sqs-dynamic-target-tracking
# sets AWS_REGION explicitly). If neither is set, region_name=None lets boto3
# fall back to the session's default provider chain (config file, IMDS, etc.)
# instead of a hardcoded region.
aws_region = os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION')
sqs = session.resource('sqs', config=config, region_name=aws_region)
cloudwatch = session.client('cloudwatch', config=config, region_name=aws_region)

queue_name = os.environ['queue_name']
app_metric_name = os.environ['app_metric_name']
metric_type = os.environ['metric_type']
metric_namespace = os.environ['metric_namespace']

# Cap simulated processing time at a sane maximum (15 minutes) so a bogus
# message cannot stall a consumer indefinitely.
MAX_PROCESSING_DURATION_SECONDS = 900

# Graceful shutdown flag, flipped by the SIGTERM handler. The Dockerfile uses
# an exec-form ENTRYPOINT so ECS's SIGTERM on scale-in/stop reaches Python;
# we finish the message currently being processed, then exit 0.
shutdown_requested = False


def handle_sigterm(signum, frame):
    global shutdown_requested
    logger.info('SIGTERM received - will finish the current message and exit')
    shutdown_requested = True


def validate_duration(value):
    """Validate the 'duration' field of a message body.

    The duration must be a non-negative real number (booleans are rejected
    even though they are ints). Values above MAX_PROCESSING_DURATION_SECONDS
    are capped rather than rejected. Returns the (possibly capped) duration
    as a float. Raises ValueError for anything invalid.
    """
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError('duration must be a number, got {!r}'.format(value))
    duration = float(value)
    if duration != duration:  # NaN check
        raise ValueError('duration must not be NaN')
    if duration < 0:
        raise ValueError('duration must be non-negative, got {}'.format(duration))
    if duration > MAX_PROCESSING_DURATION_SECONDS:
        logger.warning(
            'duration %s exceeds max %s seconds - capping',
            duration, MAX_PROCESSING_DURATION_SECONDS,
        )
        duration = MAX_PROCESSING_DURATION_SECONDS
    return duration


def parse_message(message):
    """Parse and validate a queue message.

    Returns the validated processing duration in seconds.
    Raises ValueError for malformed JSON or an invalid duration.
    """
    try:
        message_body = json.loads(message.body)
    except (json.JSONDecodeError, TypeError) as error:
        raise ValueError('message body is not valid JSON: {}'.format(error))
    if not isinstance(message_body, dict):
        raise ValueError(
            'message body must be a JSON object, got {!r}'.format(message_body)
        )
    return validate_duration(message_body.get('duration'))


def publishMetricValue(metricValue):

    now = datetime.datetime.now()
    logger.info('Time {} publishMetricValue with metric_namespace {} app_metric_name {} metricValue {} metric_type {} queue_name {}'.format(now, metric_namespace, app_metric_name, metricValue, metric_type, queue_name))
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


def main():

    # Initialize variables
    logger.info('Environment queue_name {} app_metric_name {} metric_type {} metric_namespace {}'.format(queue_name, app_metric_name, metric_type, metric_namespace))
    logger.info('Calling get_queue_by_name....')
    queue = sqs.get_queue_by_name(QueueName=queue_name)
    batchSize = 1
    queueWaitTime = 5

    signal.signal(signal.SIGTERM, handle_sigterm)

    # start continuous loop
    logger.info('Starting queue consumer process....')
    while not shutdown_requested:

        try:

            # Read messages from queue
            logger.info('Polling messages from the processing queue')
            messages = queue.receive_messages(AttributeNames=['All'], MaxNumberOfMessages=batchSize, WaitTimeSeconds=queueWaitTime)
            if not messages: continue

            logger.info('-- Received {} messages'.format(len(messages)))

            # Process messages
            for message in messages:
                now = datetime.datetime.now()

                try:
                    processingDuration = parse_message(message)
                except ValueError as error:
                    # Malformed message (bad JSON or bad duration). We log and
                    # deliberately do NOT delete it: the processing queue has a
                    # FIFO DLQ with a redrive policy (maxReceiveCount=5) defined
                    # in terraform/fargate-examples/sqs-dynamic-target-tracking,
                    # so after 5 failed receives SQS moves the message to the
                    # DLQ where it is preserved for inspection instead of being
                    # silently discarded or retried forever. The producer uses a
                    # unique MessageGroupId per message, so an in-flight poison
                    # message does not block other messages.
                    logger.error('Malformed message %s skipped (will redrive to DLQ after maxReceiveCount): %s', message.message_id, error)
                    continue

                logger.info('Time {} Processing message_id {} for {} seconds...'.format(now, message.message_id, processingDuration))
                time.sleep(processingDuration)

                # Delete the message
                message.delete()
                now = datetime.datetime.now()

                # Report message duration to cloudwatch
                publishMetricValue(processingDuration)

                if shutdown_requested:
                    break

        except ClientError as error:
            logger.error('SQS Service Exception - Code: {}, Message: {}'.format(error.response['Error']['Code'], error.response['Error']['Message']))
            continue

        except Exception as e:
            logger.error('Unexpected error - {}'.format(e))

    logger.info('Shutdown requested - exiting cleanly')
    sys.exit(0)


if __name__ == "__main__":
    main()
