# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Purpose

Demonstrate basic message operations in Amazon Simple Queue Service (Amazon SQS).
"""

import logging
import sys

import boto3
from botocore.exceptions import ClientError

QUEUE_URL = None

logger = logging.getLogger(__name__)
sqs = boto3.resource('sqs')

def usage_demo():
    """
    Shows how to:
    * Read the lines from this Python file and send the lines in
      batches of 10 as messages to a queue.
    * Receive the messages in batches until the queue is empty.
    * Reassemble the lines of the file and verify they match the original file.
    """
    def pack_message(msg_path, msg_body, msg_line):
        return {
            'body': msg_body,
            'attributes': {
                'path': {'StringValue': msg_path, 'DataType': 'String'},
                'line': {'StringValue': str(msg_line), 'DataType': 'String'}
            }
        }

    def unpack_message(msg):
        return (msg.message_attributes['path']['StringValue'],
                msg.body,
                int(msg.message_attributes['line']['StringValue']))

    print('-'*88)
    print("Welcome to the Amazon Simple Queue Service (Amazon SQS) demo!")
    print('-'*88)

    queue = QUEUE_URL

    with open(__file__) as file:
        lines = file.readlines()

    line = 0
    batch_size = 10
    received_lines = [None]*len(lines)
    print(f"Sending file lines in batches of {batch_size} as messages.")
    while line < len(lines):
        messages = [pack_message(__file__, lines[index], index)
                    for index in range(line, min(line + batch_size, len(lines)))]
        line = line + batch_size
        send_messages(queue, messages)
        print('.', end='')
        sys.stdout.flush()
    print(f"Done. Sent {len(lines) - 1} messages.")

    print(f"Receiving, handling, and deleting messages in batches of {batch_size}.")
    more_messages = True
    while more_messages:
        received_messages = receive_messages(queue, batch_size, 2)
        print('.', end='')
        sys.stdout.flush()
        for message in received_messages:
            path, body, line = unpack_message(message)
            received_lines[line] = body
        if received_messages:
            delete_messages(queue, received_messages)
        else:
            more_messages = False
    print('Done.')

    if all([lines[index] == received_lines[index] for index in range(len(lines))]):
        print(f"Successfully reassembled all file lines!")
    else:
        print(f"Uh oh, some lines were missed!")


    print("Thanks for watching!")
    print('-'*88)


if __name__ == '__main__':
    usage_demo()
