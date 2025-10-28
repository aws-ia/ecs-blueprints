#!/bin/bash

instanceTag=$1
tries=0
responseCode=1
while [[ $responseCode != 0 && $tries -le 10 ]]
do
  instances=$(aws ec2 describe-instances \
  --filters 'Name=tag:Blueprint,Values='$instanceTag 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].InstanceId' --output text --region us-west-2)
  instances=($(echo "$instances" | tr -s '[:space:]'))
  length=${#instances[@]}
  echo "Running instances: $length"
  if [ $length -lt 3 ]; then
    echo "Less than 3 instances are running. Waiting for instances to be in running state..."
    sleep 60
  else
    break
  fi
  (( tries++ ))
done
