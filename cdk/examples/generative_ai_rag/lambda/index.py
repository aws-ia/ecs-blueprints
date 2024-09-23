import json
import boto3
import os
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    print(f"Received event: {event}")
    print(f"Received context: {context}")

    agent = event['agent']
    action_group = event['actionGroup']
    api_path = event['apiPath']
    http_method = event['httpMethod']

    function = determine_function(api_path, http_method)
    message = execute_function(function, event)

    response_body = create_response_body(message)
    action_response = create_action_response(action_group, api_path, http_method, response_body)
    function_response = create_function_response(action_response, event['messageVersion'])

    print(f"Response: {function_response}")
    return function_response

def determine_function(api_path, http_method):
    if api_path == '/bookmark/' and http_method == 'POST':
        return 'register-bookmark'
    elif api_path == '/bookmark/' and http_method == 'GET':
        return 'get-bookmark'
    else:
        return 'unknown'

def execute_function(function, event):
    if function == 'register-bookmark':
        return register_bookmark(event)
    elif function == 'get-bookmark':
        return get_bookmarks()
    else:
        return f"Unknown function: {function}"

def register_bookmark(event):
    try:
        request_body = event.get('requestBody', {})
        properties = request_body.get('content', {}).get('application/json', {}).get('properties', [])

        params = {prop['name']: prop['value'] for prop in properties if 'name' in prop and 'value' in prop}

        session_code = params.get('sessionCode')
        session_title = params.get('sessionTitle')
        session_description = params.get('sessionDescription')

        print(f"Received sessionCode: {session_code}")
        print(f"Received sessionTitle: {session_title}")
        print(f"Received sessionDescription: {session_description}")

        if not session_code:
            return "Session code is required."

        table.put_item(
            Item={
                'sessionCode': session_code,
                'sessionTitle': session_title,
                'sessionDescription': session_description
            }
        )
        return "Bookmark has been successfully registered!"
    except ClientError as e:
        print(e.response['Error']['Message'])
        return "Failed to add bookmark."

def get_bookmarks():
    try:
        response = table.scan()
        items = response.get('Items', [])
        return json.dumps(items)
    except ClientError as e:
        print(e.response['Error']['Message'])
        return "Failed to retrieve bookmarks."

def create_response_body(message):
    return {
        "TEXT": {
            "body": message
        }
    }

def create_action_response(action_group, api_path, http_method, response_body):
    return {
        'actionGroup': action_group,
        'apiPath': api_path,
        'httpMethod': http_method,
        'httpStatusCode': 200,
        'responseBody': response_body
    }

def create_function_response(action_response, message_version):
    return {
        'response': action_response,
        'messageVersion': message_version
    }
