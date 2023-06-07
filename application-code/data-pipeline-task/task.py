from typing import List
import boto3
import os
import json
import csv
from datetime import datetime
from datetime import date
from botocore.exceptions import ClientError

def convert_to_json_string(t):
    return f'{t}'

now = date.today()
processing_date = now.strftime("%m-%d-%Y")

s3Client = boto3.client('s3')
workflowClient = boto3.client('stepfunctions')
try:
    s3BucketName = os.environ["S3_BUCKET"]
    foldername = os.environ['FOLDERNAME']
    task_token = os.environ['TASK_TOKEN']
    print (os.environ['FILES'])
    file_list = json.loads(os.environ['FILES'])
    for file in file_list:
        print ("Reading file : " + file)
        fileName = os.path.basename(file)
        clean_data = open(fileName+'_processed.csv', "w")
        faulty_data = open(fileName+'_errors.csv', "w")
        fileObj = s3Client.get_object(Bucket=s3BucketName, Key=file)
        data = fileObj['Body'].read().decode('utf-8').splitlines(True)
        reader = csv.reader(data)
        writerClean = csv.writer(clean_data, delimiter='\t', quotechar='"', quoting=csv.QUOTE_ALL)
        writerFaulty = csv.writer(faulty_data, delimiter='\t', quotechar='"', quoting=csv.QUOTE_ALL)
        rownum = 0
        number_of_clean_rows = 0
        number_of_faulty_rows = 0
        number_of_columns = 0
        for row in reader:
            if (rownum == 0):
                number_of_columns = len(row)
                print("Number of columns in file = ", len(row))
            if (len(row) == number_of_columns):
                writerClean.writerow(row)
                number_of_clean_rows = number_of_clean_rows+1
            else:
                writerFaulty.writerow(row)
                number_of_faulty_rows = number_of_faulty_rows+1
            rownum = rownum + 1

        print ("Number of rows in file : " + str(rownum))
        print ("Number of clean rows : " , str(number_of_clean_rows))
        print ("Number of faulty rows : ", str(number_of_faulty_rows))
        # print("Getting attributes of " + file)
        # response = s3Client.get_object_attributes(
        #     Bucket=s3BucketName,
        #     Key=file,
        #     ObjectAttributes=['ETag', 'Checksum', 'StorageClass', 'ObjectSize']
        # )
        # print(response)
        # FUTURE: Upload clean and faulty files to another bucket or folder

    result = {
        "id": foldername,
        "files": file_list,
        "result": "pass",
        "processing_date": processing_date,
        "code": "O"
    }
    print(result)
    if task_token:
        print("Sending success output to Step Functions with task token " + task_token)
        workflowClient.send_task_success(
            taskToken=task_token,
            output=json.dumps(result, default=convert_to_json_string)
        )
# Catch any boto3 client exception
except ClientError as e:
    result = {
        'error': e.__dict__,
        "id": foldername,
        "files": file_list,
        "processing_date": processing_date
    }
    print(result)
    if task_token:
        print("Sending failure output to Step Functions with task token " + task_token)
        workflowClient.send_task_failure(
            taskToken=task_token,
            error="DataProcessingException",
            cause=json.dumps(result, default=convert_to_json_string)
        )
# Catch any generic python exception
except Exception as e:
    result = {
        "id": foldername,
        "files": file_list,
        "result": "fail",
        "error": e,
        "cause": "processing error",
        "processing_date": processing_date
    }
    print(result)
    if task_token:
        print("Sending failure output to Step Functions with task token " + task_token)
        workflowClient.send_task_failure(
            taskToken=task_token,
            error="DataProcessingException",
            cause=json.dumps(result, default=convert_to_json_string)
        )
