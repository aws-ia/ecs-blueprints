#!/bin/bash

function usage {
    echo "usage: build.sh [-i image_name] [-r region]"
    echo "Required:"
    echo "  -i        Used to specify the build container image"
    echo "Optional:"
    echo "  -r        Region to deploy the container in. Default will use aws cli configured region"
    exit 1
}

image_flag=false
accountid=`aws sts get-caller-identity --query Account --output text`

while getopts ":i:r:" opt; do
    case "$opt" in
        i) image_flag=true; imagename=$OPTARG;;
	r) region_flag=true; regionname=$OPTARG;;
        h) usage; exit;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage;exit 1;;
        :) echo "Missing option argument for -$OPTARG" >&2; usage;exit 1;;
        *) echo "Invalid option: -$OPTARG" >&2; usage; exit 1;;
    esac
done

if  ! $image_flag
then
    echo "The image name (-i) must be included for a build to run" >&2
fi

if ! $region_flag
then
    regionname=`aws configure get region`
fi

# Login to ECR
echo ECR Login
aws ecr get-login-password --region $regionname | docker login --username AWS --password-stdin $accountid.dkr.ecr.$regionname.amazonaws.com
docker build -t $imagename --network=host .
docker tag $imagename:latest $accountid.dkr.ecr.$regionname.amazonaws.com/$imagename:latest

repositories=`aws ecr describe-repositories --region $regionname`
REPO_LIST=$(aws ecr describe-repositories --query "repositories[].repositoryName" --output text --region $regionname)
for repo in $REPO_LIST; do
  if [ "$repo" == "$imagename" ] ; then
      echo "Found existing repo for $imagename. Pushing image to this repo"
      docker push $accountid.dkr.ecr.$regionname.amazonaws.com/$imagename:latest
      echo build completed on `date`
      exit 0
  fi
done
echo "No existing repo $imagename found. Creating one and pushing image to this repo"
aws ecr create-repository --repository-name $imagename --region $regionname
docker push $accountid.dkr.ecr.$regionname.amazonaws.com/$imagename:latest
echo build completed on `date`
