import importlib.util
import pathlib
import sys
import types
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "application-code"
    / "lambda-function-queue-trigger"
    / "lambda_function.py"
)


class FakeSsm:
    def get_parameters(self, **kwargs):
        values = {
            "PIPELINE_UNPROCESSED_SQS_URL": "https://sqs.example/processing",
            "PIPELINE_ENABLED": "1",
            "PIPELINE_ECS_MAX_TASKS": "30",
            "PIPELINE_ECS_CLUSTER": "queue-cluster",
            "PIPELINE_ECS_TASK_CONTAINER": "queue-worker",
            "PIPELINE_ECS_TASK_DEFINITION": (
                "arn:aws:ecs:us-west-2:123456789012:"
                "task-definition/queue-worker:42"
            ),
            "PIPELINE_ECS_TASK_SECURITYGROUP": "sg-0123456789abcdef0",
            "PIPELINE_ECS_TASK_SUBNET": "subnet-0123456789abcdef0",
            "PIPELINE_S3_DEST_PREFIX": "processed",
        }
        return {
            "Parameters": [
                {"Name": name, "Value": value} for name, value in values.items()
            ]
        }


class FakeSqs:
    def get_queue_attributes(self, **kwargs):
        return {"Attributes": {"ApproximateNumberOfMessages": "250"}}


class FakeEcs:
    def __init__(self):
        self.list_tasks_calls = []
        self.list_task_responses = {}
        self.run_task_calls = []
        self.run_task_responses = []

    def list_tasks(self, **kwargs):
        self.list_tasks_calls.append(kwargs)
        key = (kwargs["desiredStatus"], kwargs.get("nextToken"))
        if key in self.list_task_responses:
            return self.list_task_responses[key]
        return {"taskArns": []}

    def run_task(self, **kwargs):
        self.run_task_calls.append(kwargs)
        if self.run_task_responses:
            return self.run_task_responses.pop(0)
        return {
            "tasks": [
                {"taskArn": f"arn:aws:ecs:task/{index}"}
                for index in range(kwargs["count"])
            ],
            "failures": [],
        }


class QueueTriggerTest(unittest.TestCase):
    def setUp(self):
        self.ecs = FakeEcs()
        clients = {"sqs": FakeSqs(), "ecs": self.ecs, "ssm": FakeSsm()}
        self.previous_boto3 = sys.modules.get("boto3")
        sys.modules["boto3"] = types.SimpleNamespace(
            client=lambda service: clients[service]
        )

        spec = importlib.util.spec_from_file_location("queue_trigger", MODULE_PATH)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def tearDown(self):
        if self.previous_boto3 is None:
            sys.modules.pop("boto3", None)
        else:
            sys.modules["boto3"] = self.previous_boto3

    def test_batches_run_task_and_uses_latest_revision(self):
        started = self.module.lambda_handler({}, None)

        self.assertEqual(started, 25)
        self.assertEqual(
            [call["count"] for call in self.ecs.run_task_calls],
            [10, 10, 5],
        )
        self.assertEqual(
            self.ecs.list_tasks_calls[0]["family"],
            "queue-worker",
        )
        self.assertEqual(
            [call["desiredStatus"] for call in self.ecs.list_tasks_calls],
            ["RUNNING", "PENDING"],
        )
        self.assertTrue(
            all(
                call["taskDefinition"].endswith("task-definition/queue-worker")
                for call in self.ecs.run_task_calls
            )
        )

    def test_revision_normalization_preserves_revisionless_arns(self):
        revisionless = (
            "arn:aws:ecs:us-west-2:123456789012:"
            "task-definition/queue-worker"
        )
        self.assertEqual(
            self.module.task_definition_without_revision(revisionless),
            revisionless,
        )
        self.assertEqual(
            self.module.task_definition_without_revision("queue-worker:7"),
            "queue-worker",
        )

    def test_active_task_count_includes_pending_tasks_and_all_pages(self):
        running_page = [
            f"arn:aws:ecs:task/running-{index}" for index in range(100)
        ]
        self.ecs.list_task_responses = {
            ("RUNNING", None): {
                "taskArns": running_page,
                "nextToken": "running-page-2",
            },
            ("RUNNING", "running-page-2"): {
                "taskArns": ["arn:aws:ecs:task/running-100"],
            },
            ("PENDING", None): {
                "taskArns": [
                    "arn:aws:ecs:task/pending-0",
                    "arn:aws:ecs:task/pending-1",
                ],
            },
        }

        self.assertEqual(
            self.module.active_task_count("queue-cluster", "queue-worker"),
            103,
        )
        self.assertEqual(
            [call.get("nextToken") for call in self.ecs.list_tasks_calls],
            [None, "running-page-2", None],
        )

    def test_run_task_failure_is_not_reported_as_started(self):
        self.ecs.run_task_responses = [
            {
                "tasks": [{"taskArn": "arn:aws:ecs:task/started"}],
                "failures": [
                    {
                        "arn": "arn:aws:ecs:task-definition/queue-worker",
                        "reason": "RESOURCE:FARGATE",
                    }
                ],
            }
        ]

        with self.assertRaisesRegex(
            RuntimeError,
            "ECS started 1 of 10 requested tasks",
        ):
            self.module.lambda_handler({}, None)

        self.assertEqual(len(self.ecs.run_task_calls), 1)


if __name__ == "__main__":
    unittest.main()
