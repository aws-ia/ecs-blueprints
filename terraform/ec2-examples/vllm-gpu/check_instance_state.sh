#!/bin/bash

# Usage: check_instance_state.sh <blueprint-tag> [region]
# The region comes from the second argument or the AWS_REGION environment
# variable (set by the Terraform local-exec environment block).

instanceTag=$1
region="${2:-$AWS_REGION}"
if [ -z "$region" ]; then
  echo "Error: no region provided. Pass it as the second argument or set AWS_REGION." >&2
  exit 1
fi
tries=0
responseCode=1
while [[ $responseCode != 0 && $tries -le 10 ]]
do
  instances=$(aws ec2 describe-instances \
  --filters 'Name=tag:Blueprint,Values='$instanceTag 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].InstanceId' --output text --region "$region")
  instances=($(echo "$instances" | tr -s '[:space:]'))
  length=${#instances[@]}
  echo "Running instances: $length"
  if [ $length -lt 1 ]; then
    echo "Less than 1 instance is running. Waiting for instance to be in running state..."
    sleep 60
  else
    break
  fi
  (( tries++ ))
done
