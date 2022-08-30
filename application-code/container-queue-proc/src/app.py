# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Purpose

Demonstrate basic message operations in Amazon Simple Queue Service (Amazon SQS).
"""
import urllib.parse
import logging
import sys, os
import json
import boto3
from botocore.exceptions import ClientError
try:
    from PIL import Image
except ImportError:
    import Image

logger = logging.getLogger(__name__)
sqs = boto3.resource('sqs')
s3_client = boto3.client('s3')

DEST_BUCKET = '<DESTINATION_BUCKET>'
S3_PREFIX = os.environ['PIPELINE_S3_DEST_PREFIX']


def receive_messages(queue, max_number, wait_time):
    """
    Receive a batch of messages in a single request from an SQS queue.

    :param queue: The queue from which to receive messages.
    :param max_number: The maximum number of messages to receive. The actual number
                       of messages received might be less.
    :param wait_time: The maximum time to wait (in seconds) before returning. When
                      this number is greater than zero, long polling is used. This
                      can result in reduced costs and fewer false empty responses.
    :return: The list of Message objects received. These each contain the body
             of the message and metadata and custom attributes.
    """
    try:
        messages = queue.receive_messages(
            MessageAttributeNames=['All'],
            MaxNumberOfMessages=max_number,
            WaitTimeSeconds=wait_time
        )
        for msg in messages:
            logger.info("Received message: %s: %s", msg.message_id, msg.body)
    except ClientError as error:
        logger.exception("Couldn't receive messages from queue: %s", queue)
        raise error
    else:
        return messages


def delete_messages(queue, messages):
    """
    Delete a batch of messages from a queue in a single request.

    :param queue: The queue from which to delete the messages.
    :param messages: The list of messages to delete.
    :return: The response from SQS that contains the list of successful and failed
             message deletions.
    """
    try:
        entries = [{
            'Id': str(ind),
            'ReceiptHandle': msg.receipt_handle
        } for ind, msg in enumerate(messages)]
        response = queue.delete_messages(Entries=entries)
        if 'Successful' in response:
            for msg_meta in response['Successful']:
                logger.info("Deleted %s", messages[int(msg_meta['Id'])].receipt_handle)
        if 'Failed' in response:
            for msg_meta in response['Failed']:
                logger.warning(
                    "Could not delete %s",
                    messages[int(msg_meta['Id'])].receipt_handle
                )
    except ClientError:
        logger.exception("Couldn't delete messages from queue %s", queue)
    else:
        return response


def delete_message(message):
    """
    Delete a message from a queue. Clients must delete messages after they
    are received and processed to remove them from the queue.

    :param message: The message to delete. The message's queue URL is contained in
                    the message's metadata.
    :return: None
    """
    try:
        message.delete()
        logger.info("Deleted message: %s", message.message_id)
    except ClientError as error:
        logger.exception("Couldn't delete message: %s", message.message_id)
        raise error


def resize_image(image_path, resized_path):
    size = 224, 224

    try:
        with Image.open(image_path) as image:
            image.thumbnail(size)
            image.save(resized_path)
            print("Processed " + image_path + " to " + resized_path)
    except IOError:
        print("Cannot process image " + image_path)


def usage_demo():
    """
    Shows how to:
    * Read the lines from this Python file and send the lines in
      batches of 10 as messages to a queue.
    * Receive the messages in batches until the queue is empty.
    * Reassemble the lines of the file and verify they match the original file.
    """

    def unpack_message(msg):
        return (msg.body)

    print('-'*88)
    print("Welcome to the Amazon Simple Queue Service (Amazon SQS) demo!")
    print('-'*88)

    queue = sqs.get_queue_by_name(QueueName='<QUEUE_NAME>')

    batch_size = 10
    print(f"Receiving, handling, and deleting messages in batches of {batch_size}.")
    more_messages = True
    while more_messages:
        received_messages = receive_messages(queue, batch_size, 4)
        sys.stdout.flush()

        for message in received_messages:
            msg = unpack_message(message)
            body = json.loads(msg)
            # print(body)
            if body.get('Event') == 's3:TestEvent':
                delete_message(message)
            else:
                try:
                    bucket = body['Records'][0]['s3']['bucket']['name']
                    key = urllib.parse.unquote_plus(body['Records'][0]['s3']['object']['key'], encoding='utf-8')
                except KeyError:
                    print(f"Invalid {bucket} or {key}")
                file_name = os.path.split(key)
                download_path = '/tmp/ecsproc/' + file_name[1]
                upload_path = '/tmp/ecsproc/thumbnail-{}'.format(file_name[1])

                s3_client.download_file(bucket, key, download_path)
                resize_image(download_path, upload_path)
                s3_client.upload_file(upload_path, DEST_BUCKET, S3_PREFIX + "/" + file_name[1])

        if received_messages:
            delete_messages(queue, received_messages)
        else:
            more_messages = False
    print('Done.')

    print("Thanks for watching!")
    print('-'*88)


if __name__ == '__main__':
    usage_demo()
