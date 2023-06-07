import boto3
from botocore.exceptions import ClientError
import os

client = boto3.client('s3')
bucket = os.environ['input_bucket']

class account:
    def __init__(self, id, files):
        self.id = id
        self.files = files

def lambda_handler(event, context):
    try:
        response = client.list_objects_v2(
            Bucket=bucket
        )

        # Create Map of folder to its corresponding files {<folder>:[<files>]}
        folderFiles = {}
        #print(response['Contents'])
        if 'Contents' in response:
            for obj in response['Contents']:
                # Look for 'incoming' objects
                if '/incoming/' in obj['Key']:
                    delimiters = obj['Key'].split('/incoming/')
                    # Ignore empty folders
                    if delimiters[1] != '':
                        print(delimiters[0]+':'+delimiters[1])
                        # If entry already exists in folder list, append file to folder's file list
                        # else create folder entry and add file
                        if delimiters[0] in folderFiles:
                            folderFiles[delimiters[0]].append(obj['Key'])
                        else:
                            folderFiles[delimiters[0]] = []
                            folderFiles[delimiters[0]].append(obj['Key'])

        # Build the lambda response in the following format
        # {
        # 'accounts': [{
        #      'id':
        #      'files':
        #      }],
        # 'dataPreparationResult': true,
        # 'results': []
        #}
        details = {}
        folders = []
        details['dataPreparationResult'] = False if len(folderFiles) == 0 else True
        for folder in folderFiles:
            detail = {}
            detail['foldername'] = folder
            detail['files'] = folderFiles[folder]
            folders.append(detail)
        details['folders'] = folders
        details['results'] = []
        return {
            'statusCode': 200 if details.get('dataPreparationResult') else 404,
            'body': details
        }
    except ClientError as e:
        print(e)
        return {
            'statusCode': 500,
            'body': e.__dict__
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': e.__dict__
        }
