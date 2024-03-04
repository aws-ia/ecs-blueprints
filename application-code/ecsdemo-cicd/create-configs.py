# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. SPDX-License-Identifier: MIT-0

#Example Command
# python3 create-configs.py public.ecr.aws/docker/library/httpd:latest core-infra ecsdemo-frontend development us-west-2

import boto3
import json
import sys
import re

#input new ecs image
image = sys.argv[1]

#input ecs cluster name
cluster_name = sys.argv[2]

#input ecs service name
service_name = sys.argv[3]

#input app environment
app_environment = sys.argv[4]

#input region
region = sys.argv[5]

################################################################################
# AppSpec
################################################################################

# AWS ECS client
ecs_client = boto3.client('ecs')

service_information = ecs_client.describe_services(
    cluster=cluster_name,
    services=[
        service_name,
    ],
)

subnets=service_information['services'][0]['taskSets'][0]['networkConfiguration']['awsvpcConfiguration']['subnets']
security_groups=service_information['services'][0]['taskSets'][0]['networkConfiguration']['awsvpcConfiguration']['securityGroups']
container_name=service_information['services'][0]['taskSets'][0]['loadBalancers'][0]['containerName']
task_definition=service_information['services'][0]['taskDefinition']

# Removing the last colon and the following numbers
updated_arn = re.sub(r':\d+$', '', task_definition)

# Extracting task revision numbers
rev_number = re.findall(r'\d+$', task_definition)

if rev_number:
    # Incrementing task revision numbers
    updated_numbers = int(rev_number[0]) + 1

    # Constructing the updated ARN with the incremented numbers
    new_task_definition_arn = f'{updated_arn}:{updated_numbers}'

with open('appspec.json', 'r') as file:
    app_spec_original_json = json.load(file)

app_spec_original_json['Resources'][0]['TargetService']['Properties']['TaskDefinition'] = new_task_definition_arn
app_spec_original_json['Resources'][0]['TargetService']['Properties']['LoadBalancerInfo']['ContainerName'] = container_name
app_spec_original_json['Resources'][0]['TargetService']['Properties']['NetworkConfiguration']['awsvpcConfiguration']['subnets'] = subnets
app_spec_original_json['Resources'][0]['TargetService']['Properties']['NetworkConfiguration']['awsvpcConfiguration']['securityGroups'] = security_groups

# Save the modified JSON to a new file
app_spec_file_name = f'{app_environment}-appspec.json.json'

# Save the modified JSON to a new file
with open(app_spec_file_name, 'w') as file:
    json.dump(app_spec_original_json, file, indent=2)

################################################################################
# Task Def
################################################################################

# Get task definition details using AWS SDK
response = ecs_client.describe_task_definition(taskDefinition=task_definition)

task_definition_details = response['taskDefinition']

# Extracting required values
execution_role_arn = task_definition_details['executionRoleArn']
task_role_arn = task_definition_details['taskRoleArn']
cpu = task_definition_details['cpu']
memory = task_definition_details['memory']
family = task_definition_details['family']
name = task_definition_details['containerDefinitions'][0]['name']
log_group = task_definition_details['containerDefinitions'][0]['logConfiguration']['options']['awslogs-group']
log_region = task_definition_details['containerDefinitions'][0]['logConfiguration']['options']['awslogs-region']
log_prefix = task_definition_details['containerDefinitions'][0]['logConfiguration']['options']['awslogs-stream-prefix']

# Load the original JSON file
with open('task-definition.json', 'r') as file:
    task_def_original_json = json.load(file)

# Replace placeholders with extracted values
task_def_original_json['executionRoleArn'] = execution_role_arn
task_def_original_json['taskRoleArn'] = task_role_arn
task_def_original_json['cpu'] = cpu
task_def_original_json['memory'] = memory
task_def_original_json['family'] = family
task_def_original_json['containerDefinitions'][0]['name'] = name
task_def_original_json['containerDefinitions'][0]['image'] = image
task_def_original_json['containerDefinitions'][0]['logConfiguration']['options']['awslogs-group'] = log_group
task_def_original_json['containerDefinitions'][0]['logConfiguration']['options']['awslogs-region'] = log_region
task_def_original_json['containerDefinitions'][0]['logConfiguration']['options']['awslogs-stream-prefix'] = log_prefix

# Save the modified JSON to a new file
task_def_file_name = f'{app_environment}-task-definition.json'

# Save the modified JSON to a new file
with open(task_def_file_name, 'w') as file:
    json.dump(task_def_original_json, file, indent=2)
