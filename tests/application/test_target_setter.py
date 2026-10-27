import importlib.util
import os
import pathlib
import sys
import types
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT / "application-code" / "ecs-target-setter" / "lambda_function.py"
)
ENVIRONMENT = {
    "scaling_policy_name": "queue-policy",
    "desired_latency": "100",
    "default_msg_proc_duration": "10",
    "queue_name": "processing-queue",
    "app_metric_name": "MessageProcessingDuration",
    "bpi_metric_name": "BacklogPerInstance",
    "metric_type": "ECS",
    "metric_namespace": "ECS/QueueProcessing",
    "cluster_name": "queue-cluster",
    "service_name": "queue-service",
}


class FakeCloudWatch:
    def __init__(self):
        self.metric_values = [6, 4]
        self.put_calls = []

    def get_metric_data(self, **kwargs):
        return {"MetricDataResults": [{"Values": self.metric_values}]}

    def put_metric_data(self, **kwargs):
        self.put_calls.append(kwargs)
        return {}


class FakeApplicationAutoscaling:
    def __init__(self):
        self.put_calls = []

    def describe_scaling_policies(self, **kwargs):
        return {
            "ScalingPolicies": [
                {
                    "PolicyName": "queue-policy",
                    "PolicyType": "TargetTrackingScaling",
                    "ResourceId": "service/queue-cluster/queue-service",
                    "ScalableDimension": "ecs:service:DesiredCount",
                    "TargetTrackingScalingPolicyConfiguration": {
                        "TargetValue": 1,
                    },
                }
            ]
        }

    def put_scaling_policy(self, **kwargs):
        self.put_calls.append(kwargs)
        return {}


class TargetSetterTest(unittest.TestCase):
    def setUp(self):
        self.cloudwatch = FakeCloudWatch()
        self.autoscaling = FakeApplicationAutoscaling()
        clients = {
            "cloudwatch": self.cloudwatch,
            "application-autoscaling": self.autoscaling,
        }

        self.previous_modules = {
            name: sys.modules.get(name)
            for name in ("boto3", "botocore", "botocore.config")
        }
        self.previous_environment = {
            name: os.environ.get(name) for name in ENVIRONMENT
        }

        session = types.SimpleNamespace(
            client=lambda service, config=None: clients[service]
        )
        sys.modules["boto3"] = types.SimpleNamespace(Session=lambda: session)
        sys.modules["botocore"] = types.ModuleType("botocore")
        sys.modules["botocore.config"] = types.SimpleNamespace(
            Config=lambda **kwargs: kwargs
        )
        os.environ.update(ENVIRONMENT)

        spec = importlib.util.spec_from_file_location(
            "target_setter", MODULE_PATH
        )
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def tearDown(self):
        for name, previous in self.previous_modules.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous
        for name, previous in self.previous_environment.items():
            if previous is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = previous

    def test_uses_average_duration_and_configured_service_dimension(self):
        self.module.lambda_handler({}, None)

        policy = self.autoscaling.put_calls[0][
            "TargetTrackingScalingPolicyConfiguration"
        ]
        self.assertEqual(policy["TargetValue"], 20)

        task_metric = policy["CustomizedMetricSpecification"]["Metrics"][1]
        dimensions = {
            item["Name"]: item["Value"]
            for item in task_metric["MetricStat"]["Metric"]["Dimensions"]
        }
        self.assertEqual(dimensions["ClusterName"], "queue-cluster")
        self.assertEqual(dimensions["ServiceName"], "queue-service")
        self.assertEqual(
            self.cloudwatch.put_calls[0]["MetricData"][0]["Value"],
            20,
        )

    def test_non_positive_metric_uses_positive_default(self):
        self.cloudwatch.metric_values = [0]

        self.module.lambda_handler({}, None)

        policy = self.autoscaling.put_calls[0][
            "TargetTrackingScalingPolicyConfiguration"
        ]
        self.assertEqual(policy["TargetValue"], 10)


if __name__ == "__main__":
    unittest.main()
