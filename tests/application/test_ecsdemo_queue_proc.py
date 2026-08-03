import importlib.util
import os
import pathlib
import sys
import types
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT / "application-code" / "ecsdemo-queue-proc" / "src" / "app.py"
)


class FakeMessage:
    def __init__(self, body):
        self.body = body
        self.message_id = "message-1"


class FakeSession:
    def resource(self, service, **kwargs):
        return types.SimpleNamespace()

    def client(self, service, **kwargs):
        return types.SimpleNamespace()


class EcsDemoQueueProcTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous_modules = {
            name: sys.modules.get(name)
            for name in (
                "boto3",
                "botocore",
                "botocore.exceptions",
                "botocore.config",
            )
        }
        sys.modules["boto3"] = types.SimpleNamespace(
            Session=lambda: FakeSession(),
        )
        client_error = type("ClientError", (Exception,), {})
        sys.modules["botocore"] = types.ModuleType("botocore")
        sys.modules["botocore.exceptions"] = types.SimpleNamespace(
            ClientError=client_error
        )
        sys.modules["botocore.config"] = types.SimpleNamespace(
            Config=lambda **kwargs: types.SimpleNamespace(**kwargs)
        )
        os.environ["queue_name"] = "processing-queue"
        os.environ["app_metric_name"] = "MsgProcessingDuration"
        os.environ["metric_type"] = "Single-Queue"
        os.environ["metric_namespace"] = "ECS-SQS-BPI"

        spec = importlib.util.spec_from_file_location(
            "ecsdemo_queue_proc", MODULE_PATH
        )
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    @classmethod
    def tearDownClass(cls):
        for name, previous in cls.previous_modules.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous

    # ------------------------------------------------------------------
    # validate_duration
    # ------------------------------------------------------------------

    def test_none_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.validate_duration(None)

    def test_negative_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.validate_duration(-1)

    def test_string_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.validate_duration("5")

    def test_boolean_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.validate_duration(True)

    def test_nan_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.validate_duration(float("nan"))

    def test_huge_duration_is_capped(self):
        self.assertEqual(
            self.module.validate_duration(10**9),
            self.module.MAX_PROCESSING_DURATION_SECONDS,
        )

    def test_valid_duration_is_returned(self):
        self.assertEqual(self.module.validate_duration(5), 5.0)

    def test_zero_duration_is_valid(self):
        self.assertEqual(self.module.validate_duration(0), 0.0)

    def test_float_duration_is_valid(self):
        self.assertEqual(self.module.validate_duration(2.5), 2.5)

    # ------------------------------------------------------------------
    # parse_message
    # ------------------------------------------------------------------

    def test_invalid_json_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.parse_message(FakeMessage("not json {"))

    def test_non_object_json_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.parse_message(FakeMessage("[1, 2, 3]"))

    def test_missing_duration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.parse_message(FakeMessage('{"id": 1}'))

    def test_valid_message_returns_duration(self):
        self.assertEqual(
            self.module.parse_message(
                FakeMessage('{"id": 1, "duration": 7}')
            ),
            7.0,
        )


if __name__ == "__main__":
    unittest.main()
