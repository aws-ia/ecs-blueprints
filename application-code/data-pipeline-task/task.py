import csv
import json
import os
from datetime import date

import boto3


s3_client = boto3.client("s3")
workflow_client = boto3.client("stepfunctions")


def convert_to_json_string(value):
    return f"{value}"


def send_failure(task_token, folder_name, file_list, error):
    result = {
        "id": folder_name,
        "files": file_list,
        "result": "fail",
        "error": str(error),
        "error_type": type(error).__name__,
        "cause": "processing error",
        "processing_date": date.today().strftime("%m-%d-%Y"),
    }
    print(result)

    if not task_token:
        return

    print("Sending failure output to Step Functions")
    workflow_client.send_task_failure(
        taskToken=task_token,
        error="DataProcessingException",
        cause=json.dumps(result, default=convert_to_json_string),
    )


def process_file(bucket_name, key):
    print(f"Reading file: {key}")
    file_name = os.path.basename(key)
    file_object = s3_client.get_object(Bucket=bucket_name, Key=key)
    data = file_object["Body"].read().decode("utf-8").splitlines(True)

    with open(
        f"{file_name}_processed.csv", "w", newline="", encoding="utf-8"
    ) as clean_data, open(
        f"{file_name}_errors.csv", "w", newline="", encoding="utf-8"
    ) as faulty_data:
        reader = csv.reader(data)
        clean_writer = csv.writer(
            clean_data, delimiter="\t", quotechar='"', quoting=csv.QUOTE_ALL
        )
        faulty_writer = csv.writer(
            faulty_data, delimiter="\t", quotechar='"', quoting=csv.QUOTE_ALL
        )

        row_count = 0
        clean_row_count = 0
        faulty_row_count = 0
        column_count = 0
        for row in reader:
            if row_count == 0:
                column_count = len(row)
                print("Number of columns in file =", column_count)
            if len(row) == column_count:
                clean_writer.writerow(row)
                clean_row_count += 1
            else:
                faulty_writer.writerow(row)
                faulty_row_count += 1
            row_count += 1

    print("Number of rows in file:", row_count)
    print("Number of clean rows:", clean_row_count)
    print("Number of faulty rows:", faulty_row_count)


def main():
    task_token = os.environ.get("TASK_TOKEN", "")
    folder_name = os.environ.get("FOLDERNAME")
    file_list = []

    try:
        bucket_name = os.environ["S3_BUCKET"]
        folder_name = os.environ["FOLDERNAME"]
        task_token = os.environ["TASK_TOKEN"]
        file_list = json.loads(os.environ["FILES"])
        if not isinstance(file_list, list):
            raise ValueError("FILES must contain a JSON array")

        for key in file_list:
            process_file(bucket_name, key)

        result = {
            "id": folder_name,
            "files": file_list,
            "result": "pass",
            "processing_date": date.today().strftime("%m-%d-%Y"),
            "code": "O",
        }
        print(result)
        workflow_client.send_task_success(
            taskToken=task_token,
            output=json.dumps(result, default=convert_to_json_string),
        )
    except Exception as error:
        try:
            send_failure(
                task_token,
                folder_name,
                file_list,
                error,
            )
        except Exception as callback_error:
            print(f"Unable to report task failure: {callback_error}")
        raise


if __name__ == "__main__":
    main()
